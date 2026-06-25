defmodule SolidAsh.Resources.PodResource do
  @moduledoc """
  A persisted Solid resource inside a pod.

  The path and content metadata remain queryable for protocol handling. The
  body and RDF metadata are encrypted before storage.
  """

  use Ash.Resource,
    otp_app: :solid_ash,
    domain: SolidAsh.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak]

  postgres do
    table("solid_ash_pod_resources")
    repo(&SolidAsh.Config.repo!/2)

    references do
      reference(:pod, on_delete: :delete)
    end
  end

  cloak do
    vault(SolidAsh.Vault)
    attributes([:body, :rdf_metadata])
  end

  code_interface do
    define(:read)
    define(:create)
    define(:update_body)
    define(:destroy)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :pod_id,
        :path,
        :kind,
        :content_type,
        :etag,
        :body,
        :rdf_metadata
      ])
    end

    update :update_body do
      accept([:content_type, :etag, :body, :rdf_metadata])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:path, :string, allow_nil?: false, public?: true)

    attribute :kind, :atom do
      constraints(one_of: [:container, :resource])
      allow_nil?(false)
      public?(true)
    end

    attribute(:content_type, :string, public?: true)
    attribute(:etag, :string, public?: true)
    attribute(:body, :binary, public?: true)
    attribute(:rdf_metadata, :map, public?: true, default: %{})

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :pod, SolidAsh.Resources.Pod do
      allow_nil?(false)
      attribute_writable?(true)
      attribute_type(:uuid)
    end
  end

  identities do
    identity(:unique_resource_path_per_pod, [:pod_id, :path])
  end
end
