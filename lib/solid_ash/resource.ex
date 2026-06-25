defmodule SolidAsh.Resource do
  @moduledoc """
  A Solid resource contained by a storage.

  Containers are resources whose paths end in `/`. Non-container resources may
  hold arbitrary bytes plus a content type.
  """

  alias SolidAsh.{Storage, Uri}

  @enforce_keys [:storage_id, :path, :uri, :kind]
  defstruct [
    :storage_id,
    :path,
    :uri,
    :kind,
    :content_type,
    :body,
    :etag,
    metadata: %{}
  ]

  @type kind :: :container | :resource

  @type t :: %__MODULE__{
          storage_id: term(),
          path: String.t(),
          uri: String.t(),
          kind: kind(),
          content_type: String.t() | nil,
          body: binary() | nil,
          etag: String.t() | nil,
          metadata: map()
        }

  @spec new(Storage.t(), String.t(), map() | keyword()) :: {:ok, t()} | {:error, term()}
  def new(%Storage{} = storage, path, attrs \\ []) do
    attrs = Map.new(attrs)

    with {:ok, path} <- Uri.normalize_resource_path(path),
         {:ok, uri} <- Uri.resource_uri(storage.base_uri, path) do
      {:ok,
       %__MODULE__{
         storage_id: storage.id,
         path: path,
         uri: uri,
         kind: kind_for_path(path),
         content_type: Map.get(attrs, :content_type),
         body: Map.get(attrs, :body),
         etag: Map.get(attrs, :etag),
         metadata: Map.get(attrs, :metadata, %{})
       }}
    end
  end

  @spec kind_for_path(String.t()) :: kind()
  def kind_for_path(path), do: if(Uri.container_path?(path), do: :container, else: :resource)
end
