defmodule SolidAsh.Security do
  @moduledoc """
  Narrow non-applicability gate for the Cloak AES-CTR advisory.

  A complete inventory must include every configured or active vault. Only the
  natively guarded `SolidAsh.Vault` is supported. Other compiled Cloak vaults
  are rejected even when currently unconfigured: imperative startup options or
  custom callbacks cannot be attested by inspecting application configuration.

  This gate does not start applications or workers, inspect encrypted records,
  migrate ciphertext or disclose configuration in errors. Distribution owners
  must additionally pin and verify the implementation they trust.
  """

  alias SolidAsh.Vault

  @advisory "EEF-CVE-2026-95105"
  @inventory_error "Cloak advisory acknowledgement requires a complete, safe native vault inventory"
  @ignore_error "Cloak advisory acknowledgement forbids pre-existing audit ignores"

  @doc """
  Validates an explicitly complete inventory of `{otp_app, vault_module}` pairs.

  Only `{:solid_ash, SolidAsh.Vault}` is allowed. Empty inventory is accepted
  only when no configured or active vault exists and no other compiled Cloak
  vault is found. Every configured and active native configuration is checked.
  Missing, extra, duplicate, custom and unsafe entries fail closed.

  Returns sanitized strings, never cipher configuration or provider errors.
  The caller owns the separate assertion that the inventory is complete and
  must load all known host/dependency application metadata before discovery
  (with `Application.load/1`, not starting applications). The owning task does
  this automatically for the root and resolved dependency applications.
  """
  @spec validate_inventory(term()) :: :ok | {:error, String.t()}
  def validate_inventory(inventory) do
    configured = configured_vaults()
    active = active_vaults()
    compiled = compiled_vaults()

    with true <- is_list(inventory),
         true <- Enum.all?(inventory, &(&1 == {:solid_ash, Vault})),
         true <- length(inventory) == length(Enum.uniq(inventory)),
         true <- Enum.all?(compiled, &(&1 == Vault)),
         true <- Enum.all?(configured, &(&1 == {:solid_ash, Vault})),
         true <- Enum.all?(active, &(&1 == Vault)),
         expected = Enum.uniq(configured ++ Enum.map(active, &{:solid_ash, &1})),
         true <- Enum.sort(inventory) == Enum.sort(expected),
         true <- Vault.security_policy_version() == 1,
         :ok <- validate_configured(configured),
         :ok <- validate_active(active) do
      :ok
    else
      _other -> {:error, @inventory_error}
    end
  rescue
    _error -> {:error, @inventory_error}
  catch
    _kind, _reason -> {:error, @inventory_error}
  end

  @doc """
  Runs an audit callback with exactly the reviewed Cloak advisory acknowledged.

  The inventory is validated first. Existing environment ignores are forbidden
  (including retirement ignores). The original environment is restored even
  when the callback raises or throws. The host task must also reject permanent
  project audit ignores and provide its explicit completeness marker.
  """
  @spec with_advisory_acknowledgement(term(), (-> result)) :: result | {:error, String.t()}
        when result: term()
  def with_advisory_acknowledgement(inventory, audit) when is_function(audit, 0) do
    with :ok <- validate_inventory(inventory), :ok <- no_environment_ignores() do
      previous = System.get_env("HEX_IGNORE_ADVISORIES")

      try do
        System.put_env("HEX_IGNORE_ADVISORIES", @advisory)
        audit.()
      after
        restore_environment("HEX_IGNORE_ADVISORIES", previous)
      end
    end
  end

  defp no_environment_ignores do
    if Enum.any?(["HEX_IGNORE_ADVISORIES", "HEX_IGNORE_RETIREMENTS"], fn key ->
         System.get_env(key) not in [nil, ""]
       end) do
      {:error, @ignore_error}
    else
      :ok
    end
  end

  defp restore_environment(key, nil), do: System.delete_env(key)
  defp restore_environment(key, value), do: System.put_env(key, value)

  defp configured_vaults do
    for {app, _description, _version} <- Application.loaded_applications(),
        {module, config} <- Application.get_all_env(app),
        cloak_vault?(module) or cipher_configuration?(config) do
      {app, module}
    end
  end

  defp active_vaults do
    Enum.flat_map(:ets.all(), fn table ->
      case table_module(table) do
        nil ->
          if table_cipher_configuration?(table), do: [:unsupported_vault], else: []

        module ->
          if cloak_vault?(module) or table_cipher_configuration?(table), do: [module], else: []
      end
    end)
    |> Enum.uniq()
  end

  defp table_module(table) do
    name = :ets.info(table, :name)

    if is_atom(name) and String.ends_with?(Atom.to_string(name), ".Config") do
      name |> Atom.to_string() |> String.trim_trailing(".Config") |> String.to_existing_atom()
    end
  rescue
    _error -> nil
  end

  defp table_cipher_configuration?(table) do
    case :ets.lookup(table, :config) do
      [{:config, config}] -> cipher_configuration?(config)
      _other -> false
    end
  rescue
    _error -> false
  end

  defp cipher_configuration?(config) when is_list(config) do
    Keyword.keyword?(config) and Keyword.has_key?(config, :ciphers)
  end

  defp cipher_configuration?(config) when is_map(config), do: Map.has_key?(config, :ciphers)
  defp cipher_configuration?(_config), do: false

  defp compiled_vaults do
    # Read BEAM attributes without loading arbitrary modules or invoking their
    # on_load callbacks. Memory-compiled modules are inspected only if loaded.
    available =
      Enum.flat_map(:code.all_available(), fn {_name, path, _loaded} ->
        case :beam_lib.chunks(path, [:attributes]) do
          {:ok, {module, [{:attributes, attributes}]}} ->
            if cloak_behaviour?(attributes), do: [module], else: []

          _other ->
            []
        end
      end)

    loaded =
      for {module, _path} <- :code.all_loaded(), cloak_vault?(module), do: module

    Enum.uniq(available ++ loaded)
  end

  defp cloak_vault?(module) when is_atom(module) do
    if :code.is_loaded(module) != false do
      cloak_behaviour?(module.module_info(:attributes))
    else
      case :code.which(module) do
        path when is_list(path) ->
          case :beam_lib.chunks(path, [:attributes]) do
            {:ok, {_module, [{:attributes, attributes}]}} -> cloak_behaviour?(attributes)
            _other -> false
          end

        _other ->
          false
      end
    end
  rescue
    _error -> false
  end

  defp cloak_vault?(_module), do: false

  defp cloak_behaviour?(attributes) do
    attributes |> Keyword.get_values(:behaviour) |> List.flatten() |> Enum.member?(Cloak.Vault)
  end

  defp validate_configured([]), do: :ok

  defp validate_configured([{:solid_ash, Vault}]) do
    Vault.validate_configuration(Application.get_env(:solid_ash, Vault))
  end

  defp validate_active([]), do: :ok
  defp validate_active([Vault]), do: Vault.validate_runtime_configuration()
end
