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

- AshCloak 0.4.0 addresses unsafe deserialization and plaintext-argument leakage:
  [deserialization advisory](https://github.com/ash-project/ash_cloak/security/advisories/GHSA-rc26-mrm2-6pf9),
  [plaintext advisory](https://github.com/ash-project/ash_cloak/security/advisories/GHSA-qp4v-vvrg-8ggx).
- AshPostgres 2.13.0 addresses failed tenant-rename handling:
  [advisory](https://github.com/ash-project/ash_postgres/security/advisories/GHSA-6fqq-j9c4-5766).
- AshSql 0.7.1 addresses loss of the tenant prefix in aggregate queries:
  [advisory](https://github.com/ash-project/ash_sql/security/advisories/GHSA-ww8j-58rc-f8h3).
- Postgrex 0.22.4 addresses the streamed-statement comment injection:
  [EEF advisory](https://cna.erlef.org/cves/CVE-2026-66838.html).

JournalAsh enforces Decimal 3.x. Hex currently labels all Decimal versions with
`EEF-CVE-2026-32686`, while the [EEF CNA](https://cna.erlef.org/cves/CVE-2026-32686.html)
identifies 3.0.0 as fixed. The project acknowledges only that advisory ID;
`mix hex.audit` still fails on other findings. Remove the acknowledgement once
the feed is corrected.
