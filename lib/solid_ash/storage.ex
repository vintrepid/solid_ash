defmodule SolidAsh.Storage do
  @moduledoc """
  A Solid storage root container.

  A storage is the URI space owned by one or more agents. The owner is tracked
  as a WebID URI; host applications can map that URI to their local user table.
  """

  alias SolidAsh.Uri

  @enforce_keys [:id, :base_uri, :owner_web_id]
  defstruct [:id, :base_uri, :owner_web_id, :description_uri, metadata: %{}]

  @type t :: %__MODULE__{
          id: term(),
          base_uri: String.t(),
          owner_web_id: String.t(),
          description_uri: String.t() | nil,
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    with {:ok, base_uri} <- Uri.normalize_storage_uri(fetch(attrs, :base_uri)),
         :ok <- validate_web_id(fetch(attrs, :owner_web_id)) do
      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id) || base_uri,
         base_uri: base_uri,
         owner_web_id: fetch(attrs, :owner_web_id),
         description_uri: Map.get(attrs, :description_uri),
         metadata: Map.get(attrs, :metadata, %{})
       }}
    end
  end

  defp fetch(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

  defp validate_web_id(web_id) when is_binary(web_id) do
    case URI.parse(web_id) do
      %{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) -> :ok
      _ -> {:error, :invalid_web_id}
    end
  end

  defp validate_web_id(_), do: {:error, :invalid_web_id}
end
