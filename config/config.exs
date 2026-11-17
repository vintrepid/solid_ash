import Config

config :ash, default_string_length_count: :codepoints

config :solid_ash, ash_domains: [SolidAsh.Domain]

if config_env() == :test do
  config :solid_ash, repo: SolidAsh.TestRepo
end

config :solid_ash, :security, cloak_inventory: :complete, cloak_vaults: []
