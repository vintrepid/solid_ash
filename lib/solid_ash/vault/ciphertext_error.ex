defmodule SolidAsh.Vault.CiphertextError do
  @moduledoc """
  Sanitized encryption or ciphertext authentication failure.

  Deliberately contains no plaintext, ciphertext, key, tag or provider error.
  """
  defexception message: "SolidAsh.Vault could not encrypt or authenticate ciphertext"
end
