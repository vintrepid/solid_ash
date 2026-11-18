defmodule Mix.Tasks.SolidAsh.Security do
  use Mix.Task

  @shortdoc "Checks native vault inventory before narrowly acknowledging the Cloak advisory"
  @moduledoc "Audits the native encryption boundary while retaining only its reviewed package acknowledgement.\n\n    mix solid_ash.security\n\nRequires an explicit complete inventory in the owning project:\n\n    config :solid_ash, :security,\n      cloak_inventory: :complete,\n      cloak_vaults: []\n\nInclude `{:solid_ash, SolidAsh.Vault}` when configured or active. Other vault\nimplementations, including compiled but unconfigured custom vaults, fail\nclosed. The task compiles/loads code but does not start the host application\nor workers. It never requires test files from a dependency package.\n\nOwning CI must run the dedicated vault security tests separately before\ninvoking this task, and the full suite afterwards in a separate Mix process.\nEvery other advisory/retirement remains an audit failure. An unguarded\n`mix hex.audit` still reports the Cloak advisory.\n"

  @impl Mix.Task
  def run(arguments) do
    if arguments != [], do: Mix.raise("solid_ash.security does not accept audit bypass options")
    hex_config = Mix.Project.config()[:hex] || []

    case SolidAsh.Security.validate_project_audit_policy(hex_config) do
      :ok -> :ok
      {:error, message} -> Mix.raise(message)
    end

    Mix.Task.run("compile")
    load_application_metadata!()
    security = Application.get_env(:solid_ash, :security, [])

    if not is_list(security) or not Keyword.keyword?(security) or
         Keyword.get(security, :cloak_inventory) != :complete or
         not Keyword.has_key?(security, :cloak_vaults) do
      Mix.raise("solid_ash.security requires an explicit complete Cloak vault inventory")
    end

    case SolidAsh.Security.with_advisory_acknowledgement(
           security[:cloak_vaults],
           fn environment ->
             # Hex is an installed Mix archive, not a runtime dependency. A fresh
             # Mix process avoids compiler code-path pruning of Hex/inets and
             # guarantees a real audit invocation rather than a cached task result.
             {output, status} =
               System.cmd("mix", ["hex.audit"], stderr_to_stdout: true, env: environment)

             Mix.shell().info(output)
             if status != 0, do: Mix.raise("SolidAsh guarded dependency audit failed")
             :ok
           end
         ) do
      {:error, message} -> Mix.raise(message)
      result -> result
    end
  end

  defp load_application_metadata! do
    apps = Enum.uniq([Mix.Project.config()[:app] | Mix.Project.deps_apps()])

    Enum.each(apps, fn app ->
      case Application.load(app) do
        :ok -> :ok
        {:error, {:already_loaded, ^app}} -> :ok
        _other -> Mix.raise("solid_ash.security could not load application metadata safely")
      end
    end)
  end
end
