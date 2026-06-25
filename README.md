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
- A `SolidAsh.Store` behaviour for Ash-backed stores.
- An in-memory test adapter.

It does not yet provide a complete Solid server, Solid-OIDC provider/client,
WAC parser/evaluator, ACP evaluator, RDF serialization, or Phoenix router.

## Target Specifications

Initial implementation targets:

- Solid Protocol 0.11.0: <https://solidproject.org/TR/protocol>
- Solid-OIDC: <https://solidproject.org/TR/oidc>
- Web Access Control: <https://solidproject.org/TR/wac>
- Access Control Policy: <https://solid.github.io/authorization-panel/acp-specification/>

## Roadmap

1. Storage and resource core.
2. Ash/Postgres store resources for storages, resources, versions, owners, and ACL documents.
3. Phoenix/Plug adapter for Solid HTTP methods, CORS, Link headers, ETags, and conditional writes.
4. WAC support for ACL discovery, control/read/write/append decisions, and owner bootstrap rules.
5. WebID profile document generation and discovery.
6. Solid-OIDC integration using Authorization Code + PKCE and DPoP validation.
7. ACP support as a richer authorization policy model.
8. Conformance test harness against the Solid specification test suites.

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
