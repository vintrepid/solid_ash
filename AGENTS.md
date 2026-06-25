# Agent Rules

1. SolidAsh is a first-party open-source library for Solid pod servers and Ash-backed pod data stores.
2. Keep Solid protocol, storage, identity, and authorization rules in library/domain modules. Phoenix, Plug, Mix tasks, and host apps are thin shells.
3. Prefer pure unit tests for protocol and authorization behavior. Use integration tests only for adapter boundaries.
4. Do not put Calvin-specific behavior in this library.
