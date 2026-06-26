# SolidAsh

SolidAsh is an Elixir library for building Solid pod servers and pod data
stores with Ash/Phoenix applications.

The library is intentionally shaped around an imperative shell / functional core:
HTTP controllers, LiveViews, jobs, and tasks should stay thin. Solid storage,
resource, authorization, and persistence rules belong in SolidAsh modules and
Ash-backed store implementations.

## Status

This repository is at the foundation stage. It currently provides:

- Solid storage and resource value objects.
- URI/path normalization for Solid storage roots and contained resources.
- Request-to-access-mode mapping.
- Authorization decision primitives.
- Ash/Postgres resources for persisted pods, pod resources, ACL documents, and pod contracts.
- AshCloak/Cloak support for encrypted-at-rest pod payloads.
- Employee/guide pod contract template data.
- Email normalization and obfuscation helpers for privacy-preserving clients.
- A `SolidAsh.Store` behaviour for Ash-backed stores.
- An in-memory test adapter.

It does not yet provide a complete Phoenix Solid server, Solid-OIDC
provider/client, WAC parser/evaluator, ACP evaluator, RDF serialization, or
Ash migration installer.

## Target Specifications

Initial implementation targets:

- Solid Protocol 0.11.0: <https://solidproject.org/TR/protocol>
- Solid-OIDC: <https://solidproject.org/TR/oidc>
- Web Access Control: <https://solidproject.org/TR/wac>
- Access Control Policy: <https://solid.github.io/authorization-panel/acp-specification/>

## Roadmap

1. Storage and resource core.
2. Ash/Postgres store resources for storages, resources, versions, owners, ACL documents, and contracts.
3. Ash migration installer/generator for host applications.
4. Phoenix/Plug adapter for Solid HTTP methods, CORS, Link headers, ETags, and conditional writes.
5. WAC support for ACL discovery, control/read/write/append decisions, and owner bootstrap rules.
6. WebID profile document generation and discovery.
7. Solid-OIDC integration using Authorization Code + PKCE and DPoP validation.
8. ACP support as a richer authorization policy model.
9. Conformance test harness against the Solid specification test suites.

## Encrypted Persistence

SolidAsh uses `AshCloak` with `Cloak` for sensitive persisted fields:

- `SolidAsh.Resources.Pod.profile_data`
- `SolidAsh.Resources.Pod.employment_contract`
- `SolidAsh.Resources.PodResource.body`
- `SolidAsh.Resources.PodResource.rdf_metadata`
- `SolidAsh.Resources.PodAcl.acl_graph`
- `SolidAsh.Resources.PodContract.required_data`
- `SolidAsh.Resources.PodContract.accepted_data`

Operational routing fields such as WebID, base URI, resource path, content type,
and etag remain unencrypted so the server can route requests and enforce HTTP
semantics efficiently.

## Email Privacy

SolidAsh clients should not expose raw emails unless explicitly authorized.
Use `SolidAsh.Client.Privacy.obfuscate_email/2` for response maps and
`SolidAsh.Privacy.Email.obfuscate/1` for display values.

Host applications must configure a repo and vault key:

```elixir
config :solid_ash, repo: MyApp.Repo

config :solid_ash, SolidAsh.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!(System.fetch_env!("SOLID_ASH_VAULT_KEY_BASE64"))
    }
  ]
```

## Installation

While this library is under local development:

```elixir
def deps do
  [
    {:solid_ash, path: "../forks/solid_ash"}
  ]
end
```

Once published:

```elixir
def deps do
  [
    {:solid_ash, "~> 0.1.0"}
  ]
end
```

## Development

```sh
mix deps.get
mix test
```
