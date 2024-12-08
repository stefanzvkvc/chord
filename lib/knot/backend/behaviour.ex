defmodule Knot.Backend.Behaviour do
  @moduledoc """
  Defines the behavior for backends used by Knot.
  """

  @callback set_state(context_id :: any, state :: map(), version :: integer()) :: :ok
  @callback set_delta(context_id :: any, delta ::map(), version :: integer()) :: :ok
  @callback get_state(context_id :: any) :: {map(), integer()}
  @callback get_state_history(context_id :: any, client_version :: integer()) :: list(map())
end
