# Changelog

## Unreleased

- Raise dependency minimums to patched AshCloak, AshPostgres, AshSql, and
  Postgrex versions, and document the narrowly acknowledged Decimal feed issue.
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

## Unreleased

- Require AES-256-GCM for all vault keys; reject CTR and legacy CTR fallback.
- Journal sealing now requires a running configured Cloak vault rather than an
  arbitrary encrypt/decrypt module. Existing CTR values require migration.
