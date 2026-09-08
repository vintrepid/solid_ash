# Agent Rules

1. SolidAsh is a first-party open-source library for Solid pod servers and Ash-backed pod data stores.
2. Keep Solid protocol, storage, identity, and authorization rules in library/domain modules. Phoenix, Plug, Mix tasks, and host apps are thin shells.
3. Prefer pure unit tests for protocol and authorization behavior. Use integration tests only for adapter boundaries.
4. Do not put Calvin-specific behavior in this library.
5. Preserve the dependency direction: `journal_ash` is independent of
   SolidAsh; SolidAsh depends on JournalAsh and AshAuthentication. Never add a
   reverse JournalAsh-to-SolidAsh dependency.
6. Depend on compatible public upstream Ash libraries here. The `ash_lotus`
   distribution may override them with exact, tested first-party forks; do not
   bind this standalone library to those forks unless SolidAsh itself requires
   unreleased behavior.
7. This project is pre-1.0 and its interfaces are intentionally evolvable.
   Prefer correcting a resource, action, or authorization boundary over adding
   compatibility shims. Record breaking changes, but do not promise interface
   stability before the contract has earned it.
