defmodule SolidAsh.Config do
  @moduledoc """
  Runtime configuration helpers for host applications.
  """

  @doc "The Ecto repo used by SolidAsh AshPostgres resources."
  @spec repo!() :: module()
  def repo! do
    Application.get_env(:solid_ash, :repo) ||
      raise """
      SolidAsh requires a repo:

          config :solid_ash, repo: MyApp.Repo
      """
  end

  @doc false
  @spec repo!(module(), map()) :: module()
  def repo!(_resource, _context), do: repo!()
end
