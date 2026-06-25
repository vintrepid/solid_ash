defmodule SolidAshTest do
  use ExUnit.Case, async: true

  alias SolidAsh.{Request, Resource, Storage, Uri}
  alias SolidAsh.Authorization.Decision
  alias SolidAsh.Store.Memory

  test "tracks the targeted Solid specification references" do
    assert SolidAsh.solid_protocol_version() == "0.11.0"
    assert SolidAsh.specification_references().protocol == "https://solidproject.org/TR/protocol"
  end

  test "normalizes storage roots and rejects non-http URI schemes" do
    assert Uri.normalize_storage_uri("https://pod.example/alice") ==
             {:ok, "https://pod.example/alice/"}

    assert Uri.normalize_storage_uri("file:///tmp/alice") == {:error, :unsupported_scheme}
  end

  test "normalizes contained resource paths without allowing traversal" do
    assert Uri.normalize_resource_path("notes/today.ttl") == {:ok, "/notes/today.ttl"}
    assert Uri.normalize_resource_path("../secrets") == {:error, :path_traversal}
  end

  test "builds storage and resource values" do
    storage =
      storage!(
        base_uri: "https://pod.example/alice/",
        owner_web_id: "https://id.example/alice#me"
      )

    assert storage.base_uri == "https://pod.example/alice/"

    assert {:ok, resource} =
             Resource.new(storage, "/notes/today.ttl",
               content_type: "text/turtle",
               body: "@prefix schema: <https://schema.org/> ."
             )

    assert resource.kind == :resource
    assert resource.uri == "https://pod.example/alice/notes/today.ttl"

    assert {:ok, container} = Resource.new(storage, "/notes/")
    assert container.kind == :container
  end

  test "maps HTTP methods to Solid access modes" do
    assert {:ok, get} = Request.new(method: "GET", target_uri: "https://pod.example/alice/")
    assert Request.requested_modes(get) == MapSet.new([:read])

    assert {:ok, post} = Request.new(method: :post, target_uri: "https://pod.example/alice/")
    assert Request.requested_modes(post) == MapSet.new([:append])

    assert {:ok, delete} =
             Request.new(method: "DELETE", target_uri: "https://pod.example/alice/notes/a.ttl")

    assert Request.requested_modes(delete) == MapSet.new([:write])
  end

  test "authorization decisions report allowed modes" do
    decision = Decision.allow([:read, :write])

    assert Decision.allows?(decision, :read)
    assert Decision.allows?(decision, [:read, :write])
    refute Decision.allows?(decision, :append)
    refute Decision.allows?(Decision.deny(:no_acl), :read)
  end

  test "memory store provisions storage and stores resources" do
    start_supervised!({Memory, name: Memory})

    storage =
      storage!(
        id: "alice",
        base_uri: "https://pod.example/alice/",
        owner_web_id: "https://id.example/alice#me"
      )

    assert {:ok, ^storage} = Memory.provision_storage(storage)
    assert {:ok, ^storage} = Memory.get_storage("alice")
    assert {:ok, root} = Memory.get_resource(storage, "/")
    assert root.kind == :container

    resource =
      resource!(storage, "/notes/today.ttl",
        content_type: "text/turtle",
        body: "@prefix schema: <https://schema.org/> ."
      )

    assert {:ok, ^resource} = Memory.put_resource(resource)
    assert {:ok, ^resource} = Memory.get_resource(storage, "/notes/today.ttl")
    assert {:ok, resources} = Memory.list_container(storage, "/")
    assert Enum.map(resources, & &1.path) == ["/notes/today.ttl"]
  end

  test "memory store requires an authenticated agent by default" do
    start_supervised!({Memory, name: Memory})

    anonymous = request!(method: :get, target_uri: "https://pod.example/alice/")

    authenticated =
      request!(
        method: :get,
        target_uri: "https://pod.example/alice/",
        agent_web_id: "https://id.example/alice#me"
      )

    refute Memory.authorize(anonymous).allowed?
    assert Memory.authorize(authenticated).allowed?
  end

  defp storage!(attrs) do
    assert {:ok, storage} = Storage.new(attrs)
    storage
  end

  defp resource!(storage, path, attrs) do
    assert {:ok, resource} = Resource.new(storage, path, attrs)
    resource
  end

  defp request!(attrs) do
    assert {:ok, request} = Request.new(attrs)
    request
  end
end
