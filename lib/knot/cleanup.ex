defmodule Knot.Cleanup do
  @moduledoc """
  Handles cleanup logic for stale or unnecessary data, supporting both version-based
  and time-based cleanup for contexts and devices.
  """

  # Public API for cleaning up stale deltas during sync
  def cleanup_data(context_id, device_id, version_threshold) do
    # Perform version-based cleanup during sync older than a specific version threshold
    backend().delete_deltas_by_version(context_id, device_id, version_threshold)
  end

  # Public API for periodic cleanup
  def periodic_cleanup(opts \\ []) do
    states = backend().list_states(opts)
    devices = backend().list_devices(opts)

    Enum.each(states, fn %{context_id: context_id, timestamp: state_timestamp} ->
      cleanup_time_based(context_id, state_timestamp)
    end)

    Enum.each(devices, fn %{
                            context_id: context_id,
                            device_id: device_id,
                            timestamp: delta_timestamp
                          } ->
      cleanup_device_deltas(context_id, device_id, delta_timestamp)
    end)
  end

  defp cleanup_time_based(context_id, state_timestamp) do
    state_ttl = Application.get_env(:knot, :state_ttl, :timer.hours(6))
    current_time = System.system_time(:second)

    if current_time - state_timestamp > state_ttl do
      backend().delete_state(context_id)
    end
  end

  defp cleanup_device_deltas(context_id, device_id, delta_timestamp) do
    delta_ttl = Application.get_env(:knot, :delta_ttl, :timer.hours(3))
    current_time = System.system_time(:second)

    if current_time - delta_timestamp > delta_ttl do
      backend().delete_deltas_by_time(context_id, device_id, current_time - delta_ttl)
    end
  end

  defp backend() do
    Application.get_env(:knot, :backend, Knot.Backend.ETS)
  end
end
