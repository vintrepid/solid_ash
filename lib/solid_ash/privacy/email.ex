defmodule SolidAsh.Privacy.Email do
  @moduledoc """
  Email normalization and display obfuscation helpers.

  Solid clients should use obfuscated emails for display and API responses
  unless a caller has explicit permission to see the raw address.
  """

  @type email_error :: :invalid_email

  @doc "Normalize an email for identity lookup."
  @spec normalize(String.t()) :: {:ok, String.t()} | {:error, email_error()}
  def normalize(email) when is_binary(email) do
    email = email |> String.trim() |> String.downcase()

    case String.split(email, "@", parts: 2) do
      [local, domain] when local != "" and domain != "" ->
        {:ok, local <> "@" <> domain}

      _ ->
        {:error, :invalid_email}
    end
  end

  def normalize(_email), do: {:error, :invalid_email}

  @doc "Normalize an email or raise on invalid input."
  @spec normalize!(String.t()) :: String.t()
  def normalize!(email) do
    case normalize(email) do
      {:ok, normalized} -> normalized
      {:error, reason} -> raise ArgumentError, "invalid email: #{inspect(reason)}"
    end
  end

  @doc """
  Return an obfuscated email suitable for UI and client responses.

  Examples:

      iex> SolidAsh.Privacy.Email.obfuscate("amy@example.com")
      "a**@e*****e.com"

  """
  @spec obfuscate(String.t() | nil) :: String.t() | nil
  def obfuscate(nil), do: nil

  def obfuscate(email) when is_binary(email) do
    with {:ok, email} <- normalize(email),
         [local, domain] <- String.split(email, "@", parts: 2) do
      obfuscate_local(local) <> "@" <> obfuscate_domain(domain)
    else
      _ -> "hidden"
    end
  end

  def obfuscate(_email), do: "hidden"

  @doc """
  Add an obfuscated email to a map or struct.

  By default the raw `:email` key is removed and `:obfuscated_email` is added.
  Pass `keep_raw?: true` when the caller is allowed to see both.
  """
  @spec obfuscate_in(map(), keyword()) :: map()
  def obfuscate_in(record, opts \\ []) when is_map(record) do
    keep_raw? = Keyword.get(opts, :keep_raw?, false)
    email = Map.get(record, :email) || Map.get(record, "email")
    obfuscated = obfuscate(email)

    record
    |> maybe_drop_email(keep_raw?)
    |> Map.put(:obfuscated_email, obfuscated)
  end

  defp maybe_drop_email(record, true), do: record

  defp maybe_drop_email(record, false) do
    record
    |> Map.delete(:email)
    |> Map.delete("email")
  end

  defp obfuscate_local(local) do
    first = String.slice(local, 0, 1)
    first <> String.duplicate("*", max(String.length(local) - 1, 2))
  end

  defp obfuscate_domain(domain) do
    case String.split(domain, ".", parts: 2) do
      [name, suffix] when name != "" and suffix != "" ->
        first = String.slice(name, 0, 1)
        last = String.slice(name, -1, 1)
        first <> String.duplicate("*", max(String.length(name) - 2, 3)) <> last <> "." <> suffix

      _ ->
        String.duplicate("*", max(String.length(domain), 3))
    end
  end
end
