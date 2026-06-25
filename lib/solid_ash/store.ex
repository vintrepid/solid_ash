defmodule SolidAsh.Store do
  @moduledoc """
  Behaviour for Solid pod data stores.

  A production implementation is expected to be backed by Ash resources. The
  behaviour keeps the rest of the Solid protocol code independent of the
  persistence adapter.
  """

  alias SolidAsh.{Request, Resource, Storage}
  alias SolidAsh.Authorization.Decision

  @callback provision_storage(Storage.t()) :: {:ok, Storage.t()} | {:error, term()}
  @callback get_storage(term()) :: {:ok, Storage.t()} | {:error, term()}
  @callback put_resource(Resource.t()) :: {:ok, Resource.t()} | {:error, term()}
  @callback get_resource(Storage.t(), String.t()) :: {:ok, Resource.t()} | {:error, term()}
  @callback delete_resource(Storage.t(), String.t()) :: :ok | {:error, term()}
  @callback list_container(Storage.t(), String.t()) :: {:ok, [Resource.t()]} | {:error, term()}
  @callback authorize(Request.t()) :: Decision.t()
end
