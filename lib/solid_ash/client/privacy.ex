defmodule SolidAsh.Client.Privacy do
  @moduledoc """
  Privacy transforms for Solid client responses.
  """

  alias SolidAsh.Privacy.Email

  @doc """
  Replace raw email fields with obfuscated display values.
  """
  @spec obfuscate_email(map(), keyword()) :: map()
  def obfuscate_email(record, opts \\ []), do: Email.obfuscate_in(record, opts)
end
