defmodule Knot.StateManager do
  @moduledoc """
  Orchestrates state synchronization, delta calculation.
  """
  alias Knot.{Delta, Cleanup}
  @default_backend Knot.Backend.ETS
  @default_delta_threshold 100

  @spec get_state(context_id :: any()) :: {map(), integer()}
  def get_state(context_id) do
    backend().get_state(context_id)
  end

  @spec set_state(context_id :: any(), device_id :: any(), new_state :: map()) ::
          {:ok, integer(), map(), map()}
  def set_state(context_id, device_id, new_state) do
    {old_state, old_version} = get_state(context_id)
    new_version = old_version + 1
    delta = Delta.calculate_delta(old_state, new_state)

    backend().set_state(context_id, new_state, new_version)
    backend().set_delta(context_id, device_id, delta, new_version)
    {:ok, new_version, new_state, delta}
  end

  @spec sync_state(context_id :: any(), device_id :: any(), client_version :: integer() | nil) ::
          {:full_state, map(), integer()} | {:delta, map(), integer()} | {:no_change, integer()}
  def sync_state(context_id, device_id, client_version) do
    {current_state, current_version} = get_state(context_id)

    case determine_sync_action(client_version, current_version) do
      :full_state ->
        Cleanup.cleanup_data(context_id, device_id, current_version - delta_threshold())
        {:full_state, current_state, current_version}

      :no_change ->
        {:no_change, current_version}

      :deltas ->
        delta_history = backend().get_delta(context_id, device_id, client_version)

        if delta_history == [] do
          {:full_state, current_state, current_version}
        else
          delta = Delta.merge_deltas(delta_history)
          Cleanup.cleanup_data(context_id, device_id, client_version)
          {:delta, delta, current_version}
        end
    end
  end

  @spec delete_state(context_id :: any()) :: :ok | {:error, term()}
  def delete_state(context_id) do
    backend().delete_state(context_id)
  end

  @spec delete_deltas_by_device(context_id :: any(), device_id :: any()) :: :ok | {:error, term()}
  def delete_deltas_by_device(context_id, device_id) do
    backend().delete_deltas_by_device(context_id, device_id)
  end

  defp determine_sync_action(client_version, current_version) do
    cond do
      client_version == nil or client_version < current_version - delta_threshold() ->
        :full_state

      client_version >= current_version ->
        :no_change

      true ->
        :deltas
    end
  end

  defp backend() do
    Application.get_env(:knot, :backend, @default_backend)
  end

  defp delta_threshold() do
    Application.get_env(:knot, :delta_threshold, @default_delta_threshold)
  end
end
