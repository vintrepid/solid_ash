defmodule SolidAsh.Store.Memory do
  @moduledoc """
  In-memory Solid store adapter for tests and early integration work.

  This adapter is not intended for production. It exists so the functional
  contract can be exercised before a host app wires the behaviour to Ash
  resources and a database.
  """

  use Agent

  alias SolidAsh.{Resource, Storage, Uri}
  alias SolidAsh.Authorization.Decision

  @behaviour SolidAsh.Store

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> %{storages: %{}, resources: %{}} end, name: name)
  end

  @impl true
  def provision_storage(%Storage{} = storage) do
    Agent.update(__MODULE__, fn state ->
      state
      |> put_in([:storages, storage.id], storage)
      |> put_in([:resources, {storage.id, "/"}], root_container(storage))
    end)

    {:ok, storage}
  end

  @impl true
  def get_storage(id) do
    Agent.get(__MODULE__, fn state ->
      case Map.fetch(state.storages, id) do
        {:ok, storage} -> {:ok, storage}
        :error -> {:error, :not_found}
      end
    end)
  end

  @impl true
  def put_resource(%Resource{} = resource) do
    Agent.update(__MODULE__, fn state ->
      put_in(state, [:resources, {resource.storage_id, resource.path}], resource)
    end)

    {:ok, resource}
  end

  @impl true
  def get_resource(%Storage{} = storage, path) do
    with {:ok, path} <- Uri.normalize_resource_path(path) do
      Agent.get(__MODULE__, fn state ->
        case Map.fetch(state.resources, {storage.id, path}) do
          {:ok, resource} -> {:ok, resource}
          :error -> {:error, :not_found}
        end
      end)
    end
  end

  @impl true
  def delete_resource(%Storage{} = storage, path) do
    with {:ok, path} <- Uri.normalize_resource_path(path) do
      Agent.update(__MODULE__, fn state ->
        update_in(state.resources, &Map.delete(&1, {storage.id, path}))
      end)

      :ok
    end
  end

  @impl true
  def list_container(%Storage{} = storage, path) do
    with {:ok, path} <- Uri.normalize_resource_path(path),
         true <- Uri.container_path?(path) || {:error, :not_container} do
      prefix = if path == "/", do: "/", else: path

      resources =
        Agent.get(__MODULE__, fn state ->
          state.resources
          |> Enum.filter(fn
            {{storage_id, resource_path}, _resource} ->
              storage_id == storage.id and resource_path != path and
                String.starts_with?(resource_path, prefix)
          end)
          |> Enum.map(fn {_key, resource} -> resource end)
          |> Enum.sort_by(& &1.path)
        end)

      {:ok, resources}
    end
  end

  @impl true
  def authorize(request) do
    requested_modes = SolidAsh.Request.requested_modes(request)

    if request.agent_web_id do
      Decision.allow(requested_modes)
    else
      Decision.deny(:anonymous_access_not_configured)
    end
  end

  defp root_container(storage) do
    %Resource{
      storage_id: storage.id,
      path: "/",
      uri: storage.base_uri,
      kind: :container,
      content_type: "text/turtle",
      body: nil,
      metadata: %{root?: true}
    }
  end
end
