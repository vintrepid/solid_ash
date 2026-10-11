# Changelog

## Unreleased

- **Breaking:** enforce exact AES-GCM-only ciphers throughout SolidAsh.Vault,
  including rotation decryptors, startup/cache/hot-upgrade callbacks and all
  encryption/decryption APIs. Reject CTR, legacy/custom ciphers and ambiguous
  or unsupported configuration; reject authentication failures as sanitized
  errors. Existing CTR users must migrate separately before adopting; no
  legacy fallback or automatic data migration is provided.
- Add native prepared/runtime validators and complete vault inventory discovery;
  a guarded owning audit temporarily acknowledges only EEF-CVE-2026-95105 after
  that boundary passes. Permanent project/environment audit bypasses are denied.
- Raise public upstream floors to Ash 3.34.6, AshAuthentication 4.15.0,
  Decimal 3.1.2, Spark 2.7.6 and Mint 1.10.2; retain the patched compatible AshPostgres 2.13
  maintenance series. Remove the obsolete Decimal audit acknowledgement.
- Raise dependency minimums to patched AshCloak, AshPostgres, AshSql, and
  Postgrex versions.
- Establish the one-way dependency on JournalAsh and the compatible public
  AshAuthentication contract; AshLotus may override both with its exact tested
  distribution pins.
- Make the pre-1.0 interface policy explicit: correct early resource and action
  boundaries instead of accumulating compatibility shims.

## 0.1.0-dev

- Scaffold SolidAsh as a standalone Elixir library.
- Add Solid storage/resource/request/authorization primitives.
- Add `SolidAsh.Store` behaviour and in-memory adapter.
- Add Ash/Postgres resources for persisted encrypted pod storage.
- Add AshCloak/Cloak vault support.
- Add employee/guide pod contract template data.
- Add email normalization and obfuscation helpers for Solid client responses.
