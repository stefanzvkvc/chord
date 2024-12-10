defmodule Knot.CleanupTest do
  use ExUnit.Case, async: true
  import Mox
  alias Knot.Cleanup

  setup :verify_on_exit!

  setup do
    Application.put_env(:knot, :backend, Knot.Backend.Mock)
    Application.put_env(:knot, :state_ttl, :timer.hours(6))
    Application.put_env(:knot, :delta_ttl, :timer.hours(3))
    :ok
  end

  test "cleanup_data/3 cleans up deltas below the version threshold" do
    context_id = "game:1"
    device_id = "deviceA"

    Knot.Backend.Mock
    |> expect(:delete_deltas_by_version, fn ^context_id, ^device_id, 5 -> :ok end)

    Cleanup.cleanup_data(context_id, device_id, 5)
  end

  test "periodic_cleanup/1 cleans up inactive states based on TTL" do
    context_id = "game:1"
    current_time = :os.system_time(:second)
    state_ttl = Application.get_env(:knot, :state_ttl, :timer.hours(6))
    state_timestamp = current_time - state_ttl - 1

    Knot.Backend.Mock
    |> expect(:list_states, fn _opts ->
      [%{context_id: context_id, timestamp: state_timestamp}]
    end)
    |> expect(:list_devices, fn _opts -> [] end)
    |> expect(:delete_state, fn ^context_id -> :ok end)

    Cleanup.periodic_cleanup()
  end

  test "periodic_cleanup/1 cleans up device deltas based on TTL" do
    context_id = "game:1"
    device_id = "deviceA"
    current_time = :os.system_time(:second)
    delta_ttl = Application.get_env(:knot, :delta_ttl, :timer.hours(3))
    delta_timestamp = current_time - delta_ttl - 1
    older_than_timestamp = current_time - delta_ttl

    Knot.Backend.Mock
    |> expect(:list_states, fn _opts -> [] end)
    |> expect(:list_devices, fn _opts ->
      [%{context_id: context_id, device_id: device_id, timestamp: delta_timestamp}]
    end)
    |> expect(:delete_deltas_by_time, fn ^context_id, ^device_id, ^older_than_timestamp -> :ok end)

    Cleanup.periodic_cleanup()
  end

  test "periodic_cleanup/1 does not delete active states or deltas" do
    context_id = "game:1"
    device_id = "deviceA"
    current_time = :os.system_time(:second)
    state_ttl = Application.get_env(:knot, :state_ttl, :timer.hours(6))
    delta_ttl = Application.get_env(:knot, :delta_ttl, :timer.hours(3))
    active_state_timestamp = current_time - state_ttl + 100
    active_delta_timestamp = current_time - delta_ttl + 100

    Knot.Backend.Mock
    |> expect(:list_states, fn _opts ->
      [%{context_id: context_id, timestamp: active_state_timestamp}]
    end)
    |> expect(:list_devices, fn _opts ->
      [%{context_id: context_id, device_id: device_id, timestamp: active_delta_timestamp}]
    end)

    Cleanup.periodic_cleanup()
  end

  test "periodic_cleanup/1 handles empty states and devices gracefully" do
    Knot.Backend.Mock
    |> expect(:list_states, fn _opts -> [] end)
    |> expect(:list_devices, fn _opts -> [] end)

    Cleanup.periodic_cleanup()
  end

  test "handles boundary TTL values correctly" do
    context_id = "game:1"
    device_id = "deviceA"
    current_time = :os.system_time(:second)
    state_ttl = Application.get_env(:knot, :state_ttl, :timer.hours(6))
    delta_ttl = Application.get_env(:knot, :delta_ttl, :timer.hours(3))

    # Timestamps set just outside the TTL boundary
    state_boundary_timestamp = current_time - state_ttl - 1
    exact_delta_threshold = current_time - delta_ttl

    Knot.Backend.Mock
    |> expect(:list_states, fn _opts ->
      [%{context_id: context_id, timestamp: state_boundary_timestamp}]
    end)
    |> expect(:list_devices, fn _opts ->
      [%{context_id: context_id, device_id: device_id, timestamp: exact_delta_threshold - 1}]
    end)

    # Cleanup should occur because the timestamps match TTL boundaries
    Knot.Backend.Mock
    |> expect(:delete_deltas_by_time, fn ^context_id, ^device_id, ^exact_delta_threshold ->
      :ok
    end)
    |> expect(:delete_state, fn ^context_id ->
      :ok
    end)

    Cleanup.periodic_cleanup()
    verify!()
  end

  test "handles concurrent periodic cleanup calls" do
    context_id = "game:1"
    device_id = "deviceA"
    current_time = :os.system_time(:second)
    state_ttl = Application.get_env(:knot, :state_ttl, :timer.hours(6))
    delta_ttl = Application.get_env(:knot, :delta_ttl, :timer.hours(3))
    older_than_timestamp = current_time - delta_ttl
    state_timestamp = current_time - state_ttl - 1
    delta_timestamp = current_time - delta_ttl - 1

    Knot.Backend.Mock
    |> expect(:list_states, 5, fn _opts ->
      [%{context_id: context_id, timestamp: state_timestamp}]
    end)
    |> expect(:delete_state, 5, fn ^context_id -> :ok end)

    Knot.Backend.Mock
    |> expect(:list_devices, 5, fn _opts ->
      [%{context_id: context_id, device_id: device_id, timestamp: delta_timestamp}]
    end)
    |> expect(:delete_deltas_by_time, 5, fn ^context_id, ^device_id, ^older_than_timestamp ->
      :ok
    end)

    tasks =
      Enum.map(1..5, fn _ ->
        Task.async(fn -> Cleanup.periodic_cleanup() end)
      end)

    Enum.each(tasks, &Task.await/1)
  end
end
