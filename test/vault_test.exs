defmodule SolidAsh.VaultTest do
  use ExUnit.Case, async: false
  @key :binary.copy(<<29>>, 32)

  test "encrypts with GCM, rejects tampering and never accepts CTR rotation keys" do
    config = [ciphers: [default: {Cloak.Ciphers.AES.GCM, tag: "SOLID.GCM.V1", key: @key}]]
    start_supervised!({SolidAsh.Vault, config})
    assert {:ok, encrypted} = SolidAsh.Vault.encrypt("private pod data")
    assert {:ok, "private pod data"} = SolidAsh.Vault.decrypt(encrypted)
    last = byte_size(encrypted) - 1
    <<prefix::binary-size(last), byte>> = encrypted

    refute match?(
             {:ok, value} when is_binary(value),
             SolidAsh.Vault.decrypt(prefix <> <<Bitwise.bxor(byte, 1)>>)
           )

    for cipher <- [Cloak.Ciphers.AES.CTR, Cloak.Ciphers.Deprecated.AES.CTR] do
      unsafe =
        Keyword.update!(config, :ciphers, &(&1 ++ [old: {cipher, tag: "CTR.V0", key: @key}]))

      assert_raise ArgumentError, ~r/only AES-256-GCM/, fn -> SolidAsh.Vault.init(unsafe) end
    end
  end
end
