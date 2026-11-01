defmodule SolidAsh.TestRepo do
  @moduledoc false
  use AshPostgres.Repo, otp_app: :solid_ash

  def min_pg_version, do: %Version{major: 16, minor: 0, patch: 0}
  def installed_extensions, do: ["ash-functions"]
end
