defmodule SolidAsh.Request do
  @moduledoc """
  A normalized resource access request.
  """

  @enforce_keys [:method, :target_uri]
  defstruct [:method, :target_uri, :agent_web_id, :client_id, :origin, :content_type]

  @type method :: :get | :head | :options | :post | :put | :patch | :delete

  @type t :: %__MODULE__{
          method: method(),
          target_uri: String.t(),
          agent_web_id: String.t() | nil,
          client_id: String.t() | nil,
          origin: String.t() | nil,
          content_type: String.t() | nil
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    with {:ok, method} <- normalize_method(fetch(attrs, :method)),
         {:ok, target_uri} <- validate_target_uri(fetch(attrs, :target_uri)) do
      {:ok,
       %__MODULE__{
         method: method,
         target_uri: target_uri,
         agent_web_id: fetch(attrs, :agent_web_id),
         client_id: fetch(attrs, :client_id),
         origin: fetch(attrs, :origin),
         content_type: fetch(attrs, :content_type)
       }}
    end
  end

  @spec requested_modes(t()) :: MapSet.t(atom())
  def requested_modes(%__MODULE__{method: method}) do
    method
    |> case do
      method when method in [:get, :head, :options] -> [:read]
      :post -> [:append]
      method when method in [:put, :patch, :delete] -> [:write]
    end
    |> MapSet.new()
  end

  defp fetch(attrs, key), do: Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))

  defp normalize_method(method) when is_atom(method) do
    method
    |> Atom.to_string()
    |> normalize_method()
  end

  defp normalize_method(method) when is_binary(method) do
    method =
      method
      |> String.downcase()
      |> String.to_existing_atom()

    if method in [:get, :head, :options, :post, :put, :patch, :delete] do
      {:ok, method}
    else
      {:error, :unsupported_method}
    end
  rescue
    ArgumentError -> {:error, :unsupported_method}
  end

  defp normalize_method(_), do: {:error, :unsupported_method}

  defp validate_target_uri(uri) when is_binary(uri) do
    case URI.parse(uri) do
      %{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        {:ok, uri}

      _ ->
        {:error, :invalid_target_uri}
    end
  end

  defp validate_target_uri(_), do: {:error, :invalid_target_uri}
end
