defmodule SolidAsh.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:solid_ash, SolidAsh.Vault) do
        [SolidAsh.Vault]
      else
        []
      end

    opts = [strategy: :one_for_one, name: SolidAsh.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
