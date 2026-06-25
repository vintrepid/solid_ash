defmodule SolidAsh.Domain do
  @moduledoc """
  Ash domain for Solid pod storage resources.
  """

  use Ash.Domain,
    otp_app: :solid_ash

  resources do
    resource(SolidAsh.Resources.Pod)
    resource(SolidAsh.Resources.PodResource)
    resource(SolidAsh.Resources.PodAcl)
    resource(SolidAsh.Resources.PodContract)
  end
end
