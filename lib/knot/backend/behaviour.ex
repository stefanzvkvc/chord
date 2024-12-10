defmodule Knot.Backend.Behaviour do
  @moduledoc """
  Defines the behavior for backends used by Knot.
  """

  # State operations
  @callback set_state(context_id :: any(), state :: map(), version :: integer()) :: :ok
  @callback get_state(context_id :: any()) :: {map(), integer()}
  @callback delete_state(context_id :: any()) :: :ok

  # Delta operations
  @callback set_delta(
              context_id :: any(),
              device_id :: any(),
              delta :: map(),
              version :: integer()
            ) :: :ok
  @callback get_delta(context_id :: any(), device_id :: any(), client_version :: integer()) ::
              list(map())
  @callback delete_deltas_by_device(context_id :: any(), device_id :: any()) :: :ok
  @callback delete_deltas_by_version(
              context_id :: any(),
              device_id :: any(),
              version_threshold :: integer()
            ) :: :ok
  @callback delete_deltas_by_time(
              context_id :: any(),
              device_id :: any(),
              older_than_timestamp :: integer()
            ) :: :ok

  # Listing operations
  @callback list_states(opts :: Keyword.t()) :: list(map())
  @callback list_devices(opts :: Keyword.t()) :: list(map())

  # Context activity
  @callback get_last_activity_timestamp(context_id :: any()) :: integer() | nil
end
