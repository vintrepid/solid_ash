defmodule SolidAsh.SecurityInventoryTest do
  use ExUnit.Case, async: false

  alias SolidAsh.{Security, Vault}

  @inventory [{:solid_ash, Vault}]
  @custom_vault SolidAsh.SecurityInventoryTest.CustomVault

  setup do
    previous =
      for key <- [Vault, :hidden_cipher_config, :security], into: %{} do
        {key, Application.fetch_env(:solid_ash, key)}
      end

    previous_env =
      for key <- ["HEX_IGNORE_ADVISORIES", "HEX_IGNORE_RETIREMENTS"], into: %{} do
        {key, System.get_env(key)}
      end

    Application.delete_env(:solid_ash, Vault)
    Application.delete_env(:solid_ash, :hidden_cipher_config)
    System.delete_env("HEX_IGNORE_ADVISORIES")
    System.delete_env("HEX_IGNORE_RETIREMENTS")

    on_exit(fn ->
      for {key, value} <- previous do
        case value do
          {:ok, config} -> Application.put_env(:solid_ash, key, config)
          :error -> Application.delete_env(:solid_ash, key)
        end
      end

      for {key, value} <- previous_env do
        if is_nil(value), do: System.delete_env(key), else: System.put_env(key, value)
      end
    end)

    :ok
  end

  test "a genuinely unconfigured library requires an explicitly empty inventory" do
    assert :ok = Security.validate_inventory([])
    assert {:error, _message} = Security.validate_inventory(nil)
    assert {:error, _message} = Security.validate_inventory(@inventory)
    assert is_nil(Process.whereis(Vault))
    assert :undefined == :ets.info(SolidAsh.Vault.Config)
  end

  test "configured native vault must match inventory and all static decryptors are checked" do
    safe = config()
    Application.put_env(:solid_ash, Vault, safe)
    assert :ok = Security.validate_inventory(@inventory)
    assert {:error, _message} = Security.validate_inventory([])
    assert {:error, _message} = Security.validate_inventory(@inventory ++ @inventory)
    assert {:error, _message} = Security.validate_inventory([{:other_app, Vault}])

    unsafe = [
      ciphers: safe[:ciphers] ++ [old: {Cloak.Ciphers.AES.CTR, key: secret(), tag: "old"}]
    ]

    Application.put_env(:solid_ash, Vault, unsafe)
    assert {:error, message} = Security.validate_inventory(@inventory)
    refute message =~ "synthetic-private-key-marker"
    assert is_nil(Process.whereis(Vault))
  end

  test "safe declared vault cannot hide an additional ciphers-bearing configuration" do
    Application.put_env(:solid_ash, Vault, config())
    Application.put_env(:solid_ash, :hidden_cipher_config, ciphers: [])
    assert {:error, _message} = Security.validate_inventory(@inventory)
    assert {:error, _message} = Security.validate_inventory([])

    Application.put_env(:solid_ash, :hidden_cipher_config, %{ciphers: config()[:ciphers]})
    assert {:error, _message} = Security.validate_inventory(@inventory)
  end

  test "active native vault must be declared even with no application configuration" do
    safe = config()
    Cloak.Vault.save_config(SolidAsh.Vault.Config, safe)
    assert :ok = Security.validate_inventory(@inventory)
    assert {:error, _message} = Security.validate_inventory([])

    unsafe = [ciphers: [default: {Cloak.Ciphers.AES.CTR, key: secret(), tag: "bad"}]]
    Cloak.Vault.save_config(SolidAsh.Vault.Config, unsafe)
    assert {:error, _message} = Security.validate_inventory(@inventory)
  end

  test "extra active cipher cache cannot hide behind a safe declared native vault" do
    Cloak.Vault.save_config(SolidAsh.Vault.Config, config())
    extra = :ets.new(:synthetic_extra_cipher_cache, [:protected])
    :ets.insert(extra, {:config, config()})
    assert {:error, _message} = Security.validate_inventory(@inventory)
  end

  test "compiled custom Cloak vault is rejected even when unconfigured and not started" do
    custom = @custom_vault

    try do
      Code.compile_quoted(
        quote do
          defmodule unquote(custom) do
            use Cloak.Vault, otp_app: :solid_ash
          end
        end
      )

      assert is_nil(Process.whereis(custom))
      assert {:error, _message} = Security.validate_inventory([])
      Application.put_env(:solid_ash, Vault, config())
      assert {:error, _message} = Security.validate_inventory(@inventory)
      Application.put_env(:solid_ash, custom, config())

      assert {:error, _message} =
               Security.validate_inventory(@inventory ++ [{:solid_ash, custom}])
    after
      Application.delete_env(:solid_ash, custom)
      :code.purge(custom)
      :code.delete(custom)
    end
  end

  test "acknowledgement is exact, temporary and restores the prior environment on success" do
    assert :audited =
             Security.with_advisory_acknowledgement([], fn ->
               assert "EEF-CVE-2026-95105" == System.get_env("HEX_IGNORE_ADVISORIES")
               assert is_nil(System.get_env("HEX_IGNORE_RETIREMENTS"))
               :audited
             end)

    assert is_nil(System.get_env("HEX_IGNORE_ADVISORIES"))

    System.put_env("HEX_IGNORE_ADVISORIES", "")
    assert :audited = Security.with_advisory_acknowledgement([], fn -> :audited end)
    assert "" == System.get_env("HEX_IGNORE_ADVISORIES")
  end

  test "an unloaded custom BEAM is discovered without loading or running it" do
    custom = @custom_vault

    directory =
      Path.join(
        System.tmp_dir!(),
        "solid-ash-vault-" <> Base.url_encode64(:crypto.strong_rand_bytes(12), padding: false)
      )

    File.mkdir!(directory)
    path = Path.join(directory, Atom.to_string(custom) <> ".beam")

    try do
      [{^custom, beam}] =
        Code.compile_quoted(
          quote do
            defmodule unquote(custom) do
              use Cloak.Vault, otp_app: :solid_ash
            end
          end
        )

      :code.purge(custom)
      :code.delete(custom)
      File.write!(path, beam)
      Code.prepend_path(directory)
      assert false == :code.is_loaded(custom)
      assert {:error, _message} = Security.validate_inventory([])
      assert false == :code.is_loaded(custom)
      assert is_nil(Process.whereis(custom))
    after
      Code.delete_path(directory)
      :code.purge(custom)
      :code.delete(custom)
      if File.exists?(path), do: File.rm!(path)
      File.rmdir!(directory)
    end
  end

  test "another advisory still fails audit and scoped acknowledgement is restored" do
    assert_raise Mix.Error, "unreviewed advisory remains a failure", fn ->
      Security.with_advisory_acknowledgement([], fn ->
        assert "EEF-CVE-2026-95105" == System.get_env("HEX_IGNORE_ADVISORIES")
        Mix.raise("unreviewed advisory remains a failure")
      end)
    end

    assert is_nil(System.get_env("HEX_IGNORE_ADVISORIES"))

    assert catch_throw(Security.with_advisory_acknowledgement([], fn -> throw(:audit_failed) end)) ==
             :audit_failed

    assert is_nil(System.get_env("HEX_IGNORE_ADVISORIES"))
  end

  test "missing/unsafe inventory or additional ignores prevent the audit callback" do
    forbidden = fn -> flunk("audit callback must not run") end
    assert {:error, _message} = Security.with_advisory_acknowledgement(nil, forbidden)
    Application.put_env(:solid_ash, Vault, ciphers: [])
    assert {:error, _message} = Security.with_advisory_acknowledgement(@inventory, forbidden)
    Application.delete_env(:solid_ash, Vault)

    for key <- ["HEX_IGNORE_ADVISORIES", "HEX_IGNORE_RETIREMENTS"] do
      System.put_env(key, "unexpected-ignore")
      assert {:error, _message} = Security.with_advisory_acknowledgement([], forbidden)
      assert "unexpected-ignore" == System.get_env(key)
      System.delete_env(key)
    end
  end

  test "owning task rejects bypass arguments and missing completeness metadata" do
    assert_raise Mix.Error, fn -> Mix.Tasks.SolidAsh.Security.run(["--ignore"]) end
    Application.delete_env(:solid_ash, :security)
    assert_raise Mix.Error, ~r/explicit complete/, fn -> Mix.Tasks.SolidAsh.Security.run([]) end
    Application.put_env(:solid_ash, :security, cloak_vaults: [])
    assert_raise Mix.Error, ~r/explicit complete/, fn -> Mix.Tasks.SolidAsh.Security.run([]) end
  end

  defp config do
    [
      ciphers: [
        default: {Cloak.Ciphers.AES.GCM, key: :crypto.strong_rand_bytes(32), tag: "current"}
      ]
    ]
  end

  defp secret, do: "synthetic-private-key-marker"
end
