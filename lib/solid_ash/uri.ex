defmodule SolidAsh.Uri do
  @moduledoc """
  URI helpers for Solid storage and contained resources.

  Solid paths ending in `/` denote containers. SolidAsh keeps that rule explicit
  and stores paths relative to the storage root.
  """

  @type reason ::
          :missing_uri
          | :invalid_uri
          | :unsupported_scheme
          | :uri_has_query
          | :uri_has_fragment
          | :outside_storage
          | :path_traversal

  @spec normalize_storage_uri(String.t()) :: {:ok, String.t()} | {:error, reason()}
  def normalize_storage_uri(uri) when is_binary(uri) do
    with :ok <- validate_absolute_http_uri(uri),
         :ok <- reject_query_or_fragment(uri) do
      normalized =
        uri
        |> String.trim()
        |> String.trim_trailing("/")
        |> Kernel.<>("/")

      {:ok, normalized}
    end
  end

  def normalize_storage_uri(_), do: {:error, :missing_uri}

  @spec normalize_resource_path(String.t()) :: {:ok, String.t()} | {:error, reason()}
  def normalize_resource_path(path) when is_binary(path) do
    path = String.trim(path)

    cond do
      path in ["", "/"] ->
        {:ok, "/"}

      String.contains?(path, ["../", "/.."]) or path == ".." ->
        {:error, :path_traversal}

      true ->
        {:ok, "/" <> String.trim_leading(path, "/")}
    end
  end

  def normalize_resource_path(_), do: {:error, :invalid_uri}

  @spec resource_uri(String.t(), String.t()) :: {:ok, String.t()} | {:error, reason()}
  def resource_uri(storage_uri, resource_path) do
    with {:ok, storage_uri} <- normalize_storage_uri(storage_uri),
         {:ok, resource_path} <- normalize_resource_path(resource_path) do
      relative = String.trim_leading(resource_path, "/")
      {:ok, URI.merge(storage_uri, relative) |> URI.to_string()}
    end
  end

  @spec path_for(String.t(), String.t()) :: {:ok, String.t()} | {:error, reason()}
  def path_for(storage_uri, resource_uri) do
    with {:ok, storage_uri} <- normalize_storage_uri(storage_uri),
         :ok <- validate_absolute_http_uri(resource_uri),
         :ok <- reject_query_or_fragment(resource_uri) do
      if String.starts_with?(resource_uri, storage_uri) do
        relative = String.replace_prefix(resource_uri, storage_uri, "")
        normalize_resource_path(relative)
      else
        {:error, :outside_storage}
      end
    end
  end

  @spec container_path?(String.t()) :: boolean()
  def container_path?(path), do: String.ends_with?(path, "/")

  defp validate_absolute_http_uri(uri) when is_binary(uri) do
    parsed = URI.parse(String.trim(uri))

    cond do
      parsed.scheme not in ["http", "https"] -> {:error, :unsupported_scheme}
      is_nil(parsed.host) or parsed.host == "" -> {:error, :invalid_uri}
      true -> :ok
    end
  end

  defp validate_absolute_http_uri(_), do: {:error, :invalid_uri}

  defp reject_query_or_fragment(uri) do
    parsed = URI.parse(uri)

    cond do
      parsed.query -> {:error, :uri_has_query}
      parsed.fragment -> {:error, :uri_has_fragment}
      true -> :ok
    end
  end
end
