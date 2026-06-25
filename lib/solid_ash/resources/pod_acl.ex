defmodule SolidAsh.Resources.PodAcl do
  @moduledoc """
  Encrypted WAC/ACL document associated with a Solid pod resource.
  """

  use Ash.Resource,
    otp_app: :solid_ash,
    domain: SolidAsh.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak]

  postgres do
    table("solid_ash_pod_acls")
    repo(&SolidAsh.Config.repo!/2)

    references do
      reference(:pod, on_delete: :delete)
      reference(:resource, on_delete: :delete)
    end
  end

  cloak do
    vault(SolidAsh.Vault)
    attributes([:acl_graph])
  end

  code_interface do
    define(:read)
    define(:create)
    define(:update_graph)
    define(:destroy)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:pod_id, :resource_id, :acl_path, :acl_graph])
    end

    update :update_graph do
      accept([:acl_graph])
    end
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:acl_path, :string, allow_nil?: false, public?: true)
    attribute(:acl_graph, :map, public?: true, default: %{})

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :pod, SolidAsh.Resources.Pod do
      allow_nil?(false)
      attribute_writable?(true)
      attribute_type(:uuid)
    end

    belongs_to :resource, SolidAsh.Resources.PodResource do
      allow_nil?(true)
      attribute_writable?(true)
      attribute_type(:uuid)
    end
  end

  identities do
    identity(:unique_acl_path_per_pod, [:pod_id, :acl_path])
  end
end
