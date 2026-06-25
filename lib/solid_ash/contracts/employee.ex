defmodule SolidAsh.Contracts.Employee do
  @moduledoc """
  Contract template for employee/guide Solid pods.

  The contract is deliberately data: host applications can persist this into
  `SolidAsh.Resources.PodContract.required_data` and compare it with accepted
  pod data without baking AO-specific logic into UI code.
  """

  @required_sections [
    :identity,
    :contact,
    :emergency_contact,
    :employment,
    :certifications,
    :availability,
    :payroll
  ]

  @doc "Build the default employee pod contract payload."
  @spec default(keyword()) :: map()
  def default(opts \\ []) do
    role = Keyword.get(opts, :role, :employee)
    version = Keyword.get(opts, :version, 1)

    %{
      contract_key: "solid_ash.employee_pod",
      version: version,
      role: role,
      required_sections: @required_sections,
      fields: fields_for(role),
      user_controls: user_controls(),
      employer_controls: employer_controls()
    }
  end

  @doc "Return the sections the employee/guide must keep populated."
  @spec required_sections() :: [atom()]
  def required_sections, do: @required_sections

  defp fields_for(role) do
    %{
      identity: [:legal_name, :preferred_name, :date_of_birth, :web_id],
      contact: [:email, :mobile_phone, :mailing_address],
      emergency_contact: [:name, :relationship, :phone],
      employment: [:status, :first_year_worked, :last_year_worked, :role],
      certifications: certification_fields(role),
      availability: [:season_availability, :weekly_availability, :on_call_preferences],
      payroll: [:pay_type, :tax_profile_ref, :direct_deposit_ref]
    }
  end

  defp certification_fields(:guide), do: [:first_aid, :cpr, :swiftwater, :food_handler, :driver]
  defp certification_fields(_role), do: [:first_aid, :cpr]

  defp user_controls do
    %{
      can_view: true,
      can_request_correction: true,
      can_export: true,
      can_revoke_optional_data: true
    }
  end

  defp employer_controls do
    %{
      required_for_employment: true,
      can_verify: true,
      can_retain_for_legal_period: true,
      can_suspend_access_on_termination: true
    }
  end
end
