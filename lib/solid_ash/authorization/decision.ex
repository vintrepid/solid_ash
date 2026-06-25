defmodule SolidAsh.Authorization.Decision do
  @moduledoc """
  Result of evaluating a Solid access request.
  """

  @enforce_keys [:allowed?, :modes]
  defstruct [:allowed?, :reason, modes: MapSet.new()]

  @type t :: %__MODULE__{
          allowed?: boolean(),
          reason: atom() | nil,
          modes: MapSet.t(atom())
        }

  @spec allow(Enumerable.t()) :: t()
  def allow(modes), do: %__MODULE__{allowed?: true, modes: MapSet.new(modes)}

  @spec deny(atom()) :: t()
  def deny(reason), do: %__MODULE__{allowed?: false, reason: reason, modes: MapSet.new()}

  @spec allows?(t(), atom() | Enumerable.t()) :: boolean()
  def allows?(%__MODULE__{allowed?: false}, _required), do: false

  def allows?(%__MODULE__{modes: modes}, required) when is_atom(required),
    do: MapSet.member?(modes, required)

  def allows?(%__MODULE__{modes: modes}, required) do
    required
    |> MapSet.new()
    |> MapSet.subset?(modes)
  end
end
