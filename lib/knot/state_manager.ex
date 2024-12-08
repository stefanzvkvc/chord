defmodule Knot.StateManager do
  @moduledoc """
  Orchestrates state synchronization, delta calculation, and hybrid sync for contexts.
  """

  # Fetch the current state for a given context ID
  @spec fetch_state(context_id :: any()) :: {map(), integer()}
  def fetch_state(context_id) do
    backend().get_state(context_id)
  end

  # Sync state for a given context ID
  @spec sync_state(context_id :: any(), new_state :: map()) :: {:ok, integer()}
  def sync_state(context_id, new_state) do
    {current_state, current_version} = fetch_state(context_id)

    # Increment version
    new_version = current_version + 1

    # Calculate delta
    delta = Knot.Delta.calculate_delta(current_state, new_state)

    # Save the new state and delta in the backend
    backend().set_state(context_id, new_state, new_version)
    backend().set_delta(context_id, delta, new_version)
    {:ok, new_version}
  end

  # Handle client reconnect
  @spec handle_reconnect(context_id :: any(), client_version :: integer() | nil) ::
          {:full_state, map(), integer()} | {:delta, map(), integer()} | {:no_change, integer()}
  def handle_reconnect(context_id, client_version) do
    # Fetch the current state and version
    {current_state, current_version} = fetch_state(context_id)

    cond do
      client_version == nil or client_version < current_version - delta_threshold() ->
        # Deliver full state if the client is too outdated
        {:full_state, current_state, current_version}

      client_version >= current_version ->
        # No changes if versions match or the client's version is ahead
        {:no_change, current_version}

      true ->
        # Fetch and deliver deltas for reconnect
        delta_history = backend().get_state_history(context_id, client_version)

        if delta_history == [] do
          # If no history exists for the client version, deliver full state
          {:full_state, current_state, current_version}
        else
          # Otherwise, merge and return the delta
          delta = Knot.Delta.merge_deltas(delta_history)
          {:delta, delta, current_version}
        end
    end
  end

  defp backend() do
    Application.get_env(:knot, :backend, Knot.Backend.ETS)
  end

  defp delta_threshold() do
    Application.get_env(:knot, :delta_threshold, 100)
  end
end
