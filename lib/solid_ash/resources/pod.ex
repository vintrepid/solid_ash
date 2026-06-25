defmodule SolidAsh.Resources.Pod do
  @moduledoc """
  A persisted Solid storage root for one local employee/guide pod.

  `subject_ref` is a host-application identifier such as `guide:123` or
  `user:456`. It is intentionally generic so SolidAsh stays open-source and
  Calvin-specific user/guide resources remain outside this library.
  """

  use Ash.Resource,
    otp_app: :solid_ash,
    domain: SolidAsh.Domain,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshCloak]

  postgres do
    table("solid_ash_pods")
    repo(&SolidAsh.Config.repo!/2)
  end

  cloak do
    vault(SolidAsh.Vault)
    attributes([:profile_data, :employment_contract])
  end

  code_interface do
    define(:read)
    define(:create)
    define(:update_contract)
    define(:destroy)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :subject_ref,
        :subject_kind,
        :base_uri,
        :owner_web_id,
        :status,
        :profile_data,
        :employment_contract
      ])
    end

    update :update_contract do
      accept([:status, :profile_data, :employment_contract])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:subject_ref, :string, allow_nil?: false, public?: true)

    attribute :subject_kind, :atom do
      constraints(one_of: [:employee, :guide, :land_lubber, :manager, :system])
      allow_nil?(false)
      public?(true)
    end

    attribute(:base_uri, :string, allow_nil?: false, public?: true)
    attribute(:owner_web_id, :string, allow_nil?: false, public?: true)

    attribute :status, :atom do
      constraints(one_of: [:active, :suspended, :closed])
      default(:active)
      allow_nil?(false)
      public?(true)
    end

    attribute(:profile_data, :map, public?: true, default: %{})
    attribute(:employment_contract, :map, public?: true, default: %{})

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :resources, SolidAsh.Resources.PodResource do
      destination_attribute(:pod_id)
    end

    has_many :acls, SolidAsh.Resources.PodAcl do
      destination_attribute(:pod_id)
    end

    has_many :contracts, SolidAsh.Resources.PodContract do
      destination_attribute(:pod_id)
    end
  end

  identities do
    identity(:unique_subject, [:subject_ref])
    identity(:unique_base_uri, [:base_uri])
    identity(:unique_owner_web_id, [:owner_web_id])
  end
end
