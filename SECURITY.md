# Security

SolidAsh is an experimental, pre-1.0 library. Its encrypted-at-rest storage
primitives do not by themselves provide end-to-end encryption or a complete
Solid identity and authorization implementation. Hosts own their repositories,
authentication, authorization, encryption keys, and journal retention policy.
Do not put private pod contents or credentials in logs.

Report vulnerabilities through this repository's private GitHub vulnerability
reporting channel. Do not include customer data or real credentials.

## Dependency minimums

The declared minimums prevent older host lockfiles from retaining known flaws:

- The dependency graph and guarded native audit retain the patched Ash, Spark
  and Decimal floors, including when a host begins with an older lockfile. The obsolete Decimal
  audit-feed acknowledgement has been removed.
- AshAuthentication 4.15.0 includes the public maintenance fixes, including
  single-use token redemption enforcement:
  [upstream advisory](https://github.com/team-alembic/ash_authentication/security/advisories/GHSA-23gr-vcp4-r27q).
  Hosts using AshAuthenticationPhoenix also need its separately patched
  release; that dependency is not owned by this library.
- AshCloak 0.4.0 addresses unsafe deserialization and plaintext-argument leakage:
  [deserialization advisory](https://github.com/ash-project/ash_cloak/security/advisories/GHSA-rc26-mrm2-6pf9),
  [plaintext advisory](https://github.com/ash-project/ash_cloak/security/advisories/GHSA-qp4v-vvrg-8ggx).
- AshPostgres 2.13.0 addresses failed tenant-rename handling:
  [advisory](https://github.com/ash-project/ash_postgres/security/advisories/GHSA-6fqq-j9c4-5766).
- AshSql 0.7.1 addresses loss of the tenant prefix in aggregate queries:
  [advisory](https://github.com/ash-project/ash_sql/security/advisories/GHSA-ww8j-58rc-f8h3).
- Postgrex 0.22.4 addresses the streamed-statement comment injection:
  [EEF advisory](https://cna.erlef.org/cves/CVE-2026-66838.html).
- Mint 1.10.2 addresses the remaining HTTP framing/header allocation findings:
  [published advisories](https://hex.pm/packages/mint/advisories).

## Authenticated encryption boundary

[EEF-CVE-2026-95105](https://cna.erlef.org/cves/CVE-2026-95105.html) affects
Cloak's AES-CTR and deprecated AES-CTR implementations. Changing only the
default cipher is insufficient: retaining either CTR decryptor still permits
unauthenticated ciphertext to be accepted.

`SolidAsh.Vault` therefore rejects every cipher except exactly
`Cloak.Ciphers.AES.GCM`, including non-default rotation entries. It validates
the final configuration at startup, saving, hot upgrades and every default or
explicit encrypt/decrypt call. Cipher labels and tags must be unique, keys are
32-byte binaries, tags are nonempty binaries up to 255 bytes, and IV lengths
are 12 or 16 bytes. Unsupported, legacy or custom modules, duplicate options
and unknown options fail closed. Upstream `{:ok, :error}` authentication
failures are converted into sanitized errors; only binary authenticated
plaintext is a successful decrypt result.

The host retains key ownership. This change does not generate production keys,
read or re-encrypt stored content, or provide a CTR fallback. **Existing CTR
users must plan, perform and verify their data migration separately before
adopting this version.** Retained old AES-GCM keys remain supported when their
labels and tags are unique.

## Narrow advisory acknowledgement

There is no permanent `hex.ignore_advisories` entry. Plain `mix hex.audit`
continues to report the Cloak advisory. The owning `mix solid_ash.security`
task may acknowledge **only `EEF-CVE-2026-95105`**, for one audit invocation,
after an explicitly complete inventory passes the native guard. The callback receives an explicit child-process environment; the shared
Erlang VM environment is never changed, including on errors or throws. Existing project or
environment advisory/retirement ignores are forbidden; every other finding
still fails audit.

The standalone project deliberately configures no vault or encryption key:

```elixir
config :solid_ash, :security,
  cloak_inventory: :complete,
  cloak_vaults: []
```

When a host configures or starts `SolidAsh.Vault`, it must declare
`cloak_vaults: [{:solid_ash, SolidAsh.Vault}]`. Missing, duplicate, extra or
unsafe inventory entries fail. Discovery checks loaded application
configuration, active Cloak/configuration caches, and compiled or loaded
`Cloak.Vault` behaviours. Compiled custom vaults are denied even when currently
unconfigured because imperative start options and custom callbacks cannot be
attested by inspecting a static GCM configuration. The task loads the owning
and resolved dependency application metadata to include configured but not
started applications. No host applications or workers are started by the gate.
Direct callers of `validate_inventory/1` must similarly load known application
metadata before asserting inventory completeness.

The native validator can inspect another prepared configuration, but that is
not proof that arbitrary vault callbacks continue enforcing it. This
acknowledgement does not cover unrelated vaults, direct calls to Cloak CTR,
unreviewed replacement modules, stored legacy ciphertext, or future dynamic
code/configuration changes. Distribution owners must also verify exact trusted
native source revisions, run host/inventory tests, and enforce that no such
unsafe paths are introduced. Re-audit on dependency/configuration/code changes;
remove this exception when the advisory is no longer relevant.

Owning verification should run the dedicated security boundary tests, the
guarded audit and the complete test suite in separate Mix processes. The
existing CI audit is intentionally unchanged pending separate approval for a
standing advisory-gate workflow; it continues to report the upstream Cloak
finding. The shipped guard/task does not depend on test source being present
in a consuming application.
