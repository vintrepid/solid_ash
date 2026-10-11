import Config

config :ash, default_string_length_count: :codepoints

config :solid_ash, ash_domains: [SolidAsh.Domain]

# The standalone library configures no encryption vault/key. Hosts that configure
# or supervise SolidAsh.Vault must explicitly include it in their own inventory.
config :solid_ash, :security, cloak_inventory: :complete, cloak_vaults: []
