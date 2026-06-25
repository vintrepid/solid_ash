defmodule SolidAsh do
  @moduledoc """
  Solid pod storage and authorization primitives for Ash/Phoenix applications.

  SolidAsh is intentionally split into a small functional core and thin
  adapters. The core models Solid storages, contained resources, access
  requests, and authorization decisions. Phoenix controllers, LiveViews, Plug
  routers, and Mix tasks should call into this layer rather than holding Solid
  business rules themselves.
  """

  @solid_protocol_version "0.11.0"

  @doc "The Solid Protocol version this library is initially targeting."
  @spec solid_protocol_version() :: String.t()
  def solid_protocol_version, do: @solid_protocol_version

  @doc "Primary specification references used by this implementation."
  @spec specification_references() :: %{atom() => String.t()}
  def specification_references do
    %{
      protocol: "https://solidproject.org/TR/protocol",
      oidc: "https://solidproject.org/TR/oidc",
      wac: "https://solidproject.org/TR/wac",
      acp: "https://solid.github.io/authorization-panel/acp-specification/"
    }
  end
end
