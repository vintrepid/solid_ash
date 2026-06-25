defmodule SolidAsh.Resources.PodContract do
  @moduledoc """
  Encrypted contract snapshot describing required employee/guide pod data.

  Host apps can version contracts as AO requirements evolve. The resource stores
  the contract payload encrypted while leaving status/version fields queryable.
  """

  use Ash.Resource,
    otp_app: :solid_ash,
    domain: SolidAsh.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak]

  postgres do
    table("solid_ash_pod_contracts")
    repo(&SolidAsh.Config.repo!/2)

    references do
      reference(:pod, on_delete: :delete)
    end
  end

  cloak do
    vault(SolidAsh.Vault)
    attributes([:required_data, :accepted_data])
  end

  code_interface do
    define(:read)
    define(:create)
    define(:accept)
  end

  actions do
    defaults([:read])

    create :create do
      primary?(true)
      accept([:pod_id, :contract_key, :version, :required_data, :status])
    end

    update :accept do
      accept([:accepted_data, :accepted_at, :status])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:contract_key, :string, allow_nil?: false, public?: true)
    attribute(:version, :integer, allow_nil?: false, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:draft, :offered, :accepted, :retired])
      default(:draft)
      allow_nil?(false)
      public?(true)
    end

    attribute(:required_data, :map, public?: true, default: %{})
    attribute(:accepted_data, :map, public?: true, default: %{})
    attribute(:accepted_at, :utc_datetime_usec, public?: true)

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
    identity(:unique_contract_version_per_pod, [:pod_id, :contract_key, :version])
  end
end
