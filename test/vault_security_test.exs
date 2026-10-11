defmodule SolidAsh.VaultSecurityTest do
  use ExUnit.Case, async: false

  alias SolidAsh.Vault
  alias SolidAsh.Vault.CiphertextError

  @table SolidAsh.Vault.Config

  setup do
    old_config = Application.fetch_env(:solid_ash, Vault)
    Application.delete_env(:solid_ash, Vault)

    on_exit(fn ->
      case old_config do
        {:ok, config} -> Application.put_env(:solid_ash, Vault, config)
        :error -> Application.delete_env(:solid_ash, Vault)
      end
    end)

    %{config: config()}
  end

  test "all rotation entries must be exactly authenticated GCM", %{config: safe} do
    assert :ok = Vault.validate_configuration(safe)

    for module <- [
          Cloak.Ciphers.AES.CTR,
          Cloak.Ciphers.Deprecated.AES.CTR,
          Cloak.Ciphers.Deprecated.AES.GCM,
          __MODULE__.CustomCipher,
          nil,
          :unknown
        ],
        position <- [:default, :retired] do
      bad_cipher = {module, key: :crypto.strong_rand_bytes(32), tag: "old"}

      ciphers =
        case position do
          :default -> [default: bad_cipher] ++ safe[:ciphers]
          :retired -> safe[:ciphers] ++ [retired: bad_cipher]
        end

      assert {:error, %Cloak.InvalidConfig{}} = Vault.validate_configuration(ciphers: ciphers)
    end
  end

  test "malformed, ambiguous and unsupported cipher configuration fails closed", %{config: safe} do
    {module, options} = safe[:ciphers][:default]

    invalid = [
      nil,
      %{},
      [ciphers: []],
      [ciphers: :bad],
      [ciphers: safe[:ciphers], ciphers: safe[:ciphers]],
      [ciphers: safe[:ciphers], unknown: "not ignored"],
      [ciphers: safe[:ciphers], json_library: nil],
      [ciphers: safe[:ciphers] ++ safe[:ciphers]],
      [ciphers: safe[:ciphers] ++ [other: {module, options}]],
      [ciphers: [default: {module, []}]],
      [ciphers: [default: {module, Keyword.put(options, :key, "short")}]],
      [ciphers: [default: {module, Keyword.put(options, :tag, "")}]],
      [ciphers: [default: {module, Keyword.put(options, :tag, String.duplicate("t", 256))}]],
      [ciphers: [default: {module, Keyword.put(options, :iv_length, 1)}]],
      [ciphers: [default: {module, Keyword.put(options, :iv_length, 128)}]],
      [ciphers: [default: {module, options ++ [key: options[:key]]}]],
      [ciphers: [default: {module, options ++ [algorithm: :ctr]}]],
      [ciphers: [{"not-atom", {module, options}}]]
    ]

    for value <- invalid do
      assert {:error, %Cloak.InvalidConfig{}} = Vault.validate_configuration(value)
    end

    assert :ok =
             Vault.validate_configuration(
               ciphers: [default: {module, Keyword.put(options, :iv_length, 12)}]
             )
  end

  test "invalid startup and direct init fail before a process or cache can serve", %{config: safe} do
    unsafe = ctr_config()
    assert {:error, %Cloak.InvalidConfig{}} = Vault.start_link(unsafe)
    assert {:stop, %Cloak.InvalidConfig{}} = Vault.init(unsafe)
    assert is_nil(Process.whereis(Vault))
    assert :undefined == :ets.info(@table)

    Application.put_env(:solid_ash, Vault, unsafe)
    assert {:error, %Cloak.InvalidConfig{}} = Vault.start_link()
    Application.put_env(:solid_ash, Vault, "private-key-not-a-config")
    assert {:error, %Cloak.InvalidConfig{}} = Vault.start_link(safe)
    assert {:error, %Cloak.InvalidConfig{}} = Vault.start_link("private-key-not-a-config")
    assert is_nil(Process.whereis(Vault))
  end

  test "GCM encrypts with fresh nonces and authenticates both normal and explicit rotation ciphers",
       %{config: safe} do
    # Preserve unique labels/tags while retaining an old authenticated decryptor.
    rotated = [
      ciphers: [default: safe[:ciphers][:default], retired: config("retired")[:ciphers][:default]]
    ]

    start_supervised!({Vault, rotated})
    assert :ok = Vault.validate_runtime_configuration()

    assert {:ok, first} = Vault.encrypt("synthetic article")
    assert {:ok, second} = Vault.encrypt("synthetic article")
    refute first == second
    assert {:ok, "synthetic article"} = Vault.decrypt(first)
    assert "synthetic article" == Vault.decrypt!(second)

    retired = Vault.encrypt!("old synthetic article", :retired)
    assert {:ok, "old synthetic article"} = Vault.decrypt(retired)
    assert is_binary(Vault.encrypt!("new synthetic article"))
    assert {:error, %CiphertextError{}} = Vault.encrypt("synthetic", :missing)
    assert_raise CiphertextError, fn -> Vault.encrypt!("synthetic", :missing) end
  end

  test "ciphertext, authentication tag, IV, truncation and wrong-key tampering fail closed", %{
    config: safe
  } do
    start_supervised!({Vault, safe})
    ciphertext = Vault.encrypt!("synthetic plaintext")
    header_size = byte_size(Cloak.Tags.Encoder.encode("current"))

    for corrupted <- [
          flip(ciphertext, byte_size(ciphertext) - 1),
          flip(ciphertext, header_size),
          flip(ciphertext, header_size + 16),
          flip(ciphertext, 2),
          binary_part(ciphertext, 0, header_size + 15),
          <<>>,
          :not_binary
        ] do
      assert {:error, %CiphertextError{}} = Vault.decrypt(corrupted)
      assert_raise CiphertextError, fn -> Vault.decrypt!(corrupted) end
    end

    other_ciphertext =
      Cloak.Ciphers.AES.GCM.encrypt(
        "synthetic plaintext",
        config()[:ciphers][:default] |> elem(1)
      )
      |> elem(1)

    assert {:error, %CiphertextError{}} = Vault.decrypt(other_ciphertext)
  end

  test "raw cache replacement cannot bypass any encrypt or decrypt entry point", %{config: safe} do
    # This process owns a synthetic Cloak cache, simulating a late configuration
    # replacement outside the guarded callbacks. No running vault is changed.
    Cloak.Vault.save_config(@table, safe)
    ciphertext = Vault.encrypt!("synthetic plaintext")
    Cloak.Vault.save_config(@table, ctr_config())

    assert {:error, %Cloak.InvalidConfig{}} = Vault.validate_runtime_configuration()
    assert {:error, %Cloak.InvalidConfig{}} = Vault.encrypt("synthetic")
    assert {:error, %Cloak.InvalidConfig{}} = Vault.encrypt("synthetic", :default)
    assert {:error, %Cloak.InvalidConfig{}} = Vault.decrypt(ciphertext)
    assert_raise Cloak.InvalidConfig, fn -> Vault.encrypt!("synthetic") end
    assert_raise Cloak.InvalidConfig, fn -> Vault.encrypt!("synthetic", :default) end
    assert_raise Cloak.InvalidConfig, fn -> Vault.decrypt!(ciphertext) end
    assert {:error, %Cloak.InvalidConfig{}} = Vault.json_library()
  end

  test "save callback and hot upgrade cannot cache unsafe configuration", %{config: safe} do
    Cloak.Vault.save_config(@table, safe)
    unsafe = ctr_config()

    assert {:reply, {:error, %Cloak.InvalidConfig{}}, ^unsafe} =
             Vault.handle_call(:save_config, {self(), make_ref()}, unsafe)

    assert {:error, %Cloak.InvalidConfig{}} = Vault.code_change(:previous, unsafe, [])
    assert {:ok, ^safe} = Cloak.Vault.read_config(@table)
    assert :ok = Vault.validate_runtime_configuration()

    rotated = config("rotated")
    assert {:ok, ^rotated} = Vault.code_change(:previous, rotated, [])
    assert {:ok, ^rotated} = Cloak.Vault.read_config(@table)
  end

  test "a late replaced server state does not leak an unsafe decryptor into the cache", %{
    config: safe
  } do
    pid = start_supervised!({Vault, safe})
    :sys.replace_state(pid, fn _state -> ctr_config() end)
    assert {:error, %Cloak.InvalidConfig{}} = GenServer.call(pid, :save_config)
    assert :ok = Vault.validate_runtime_configuration()
    assert {:ok, "synthetic"} = Vault.encrypt!("synthetic") |> Vault.decrypt()
  end

  test "validation and crypto errors never contain supplied secrets", %{config: safe} do
    secret = "synthetic-private-key-marker"
    unsafe = [ciphers: [default: {Cloak.Ciphers.AES.CTR, key: secret, tag: secret}]]
    assert {:error, error} = Vault.validate_configuration(unsafe)
    refute inspect(error) =~ secret
    refute Exception.message(error) =~ secret

    start_supervised!({Vault, safe})
    assert {:error, crypto_error} = Vault.decrypt(secret)
    refute inspect(crypto_error) =~ secret
    refute Exception.message(crypto_error) =~ secret
  end

  test "unconfigured encryption remains unavailable" do
    assert {:error, %Cloak.VaultNotStarted{}} = Vault.validate_runtime_configuration()
    assert {:error, %Cloak.VaultNotStarted{}} = Vault.encrypt("synthetic")
  end

  defp config(tag \\ "current") do
    [ciphers: [default: {Cloak.Ciphers.AES.GCM, key: :crypto.strong_rand_bytes(32), tag: tag}]]
  end

  defp ctr_config do
    [ciphers: [default: {Cloak.Ciphers.AES.CTR, key: :crypto.strong_rand_bytes(32), tag: "ctr"}]]
  end

  defp flip(binary, index) do
    <<prefix::binary-size(^index), byte, suffix::binary>> = binary
    prefix <> <<Bitwise.bxor(byte, 1)>> <> suffix
  end
end
