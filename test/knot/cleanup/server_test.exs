defmodule Knot.Cleanup.ServerTest do
  use ExUnit.Case, async: true
  import Mox
  alias Knot.Backend.Mock
  alias Knot.Cleanup.Server

  setup :verify_on_exit!

  setup do
    Application.put_env(:knot, :backend, Knot.Backend.Mock)

    on_exit(fn ->
      case Process.whereis(Knot.Cleanup.Server) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal)
      end
    end)

    :ok
  end

  test "triggers periodic cleanup" do
    context_id = "game:1"
    device_id = "deviceA"
    current_time = :os.system_time(:second)
    state_ttl = Application.get_env(:knot, :state_ttl, :timer.hours(6))
    delta_ttl = Application.get_env(:knot, :delta_ttl, :timer.hours(3))
    state_timestamp = current_time - state_ttl - 1
    delta_threshold = current_time - delta_ttl

    Mock
    |> expect(:list_states, fn _opts ->
      [%{context_id: context_id, timestamp: state_timestamp}]
    end)
    |> expect(:list_devices, fn _opts ->
      [%{context_id: context_id, device_id: device_id, timestamp: delta_threshold - 1}]
    end)
    |> expect(:delete_state, fn ^context_id -> :ok end)
    |> expect(:delete_deltas_by_time, fn ^context_id, ^device_id, ^delta_threshold -> :ok end)

    {:ok, pid} = Server.start_link(interval: 200, backend_opts: [])

    # Allow the server process to use the mock
    Mox.allow(Mock, self(), pid)

    # Allow the cleanup to run
    Process.sleep(300)

    # Cleanup assertions are verified by Mox expectations
    assert Process.alive?(pid)
  end

  test "reschedules cleanup after execution" do
    context_id = "game:1"
    device_id = "deviceA"
    current_time = :os.system_time(:second)
    state_ttl = Application.get_env(:knot, :state_ttl, :timer.hours(6))
    delta_ttl = Application.get_env(:knot, :delta_ttl, :timer.hours(3))
    state_timestamp = current_time - state_ttl - 1
    delta_threshold = current_time - delta_ttl

    Mock
    |> expect(:list_states, fn _opts ->
      [%{context_id: context_id, timestamp: state_timestamp}]
    end)
    |> expect(:list_devices, fn _opts ->
      [%{context_id: context_id, device_id: device_id, timestamp: delta_threshold - 1}]
    end)
    |> expect(:delete_state, fn ^context_id -> :ok end)
    |> expect(:delete_deltas_by_time, fn ^context_id, ^device_id, ^delta_threshold -> :ok end)

    {:ok, pid} = Server.start_link(interval: 100, backend_opts: [])

    # Allow the server process to use the mock
    Mox.allow(Mock, self(), pid)

    # Wait for at least one interval to pass
    Process.sleep(150)
    assert Process.alive?(pid)
  end

  test "uses backend_opts for periodic cleanup" do
    Mock
    |> expect(:list_states, fn opts ->
      assert opts[:limit] == 10
      []
    end)
    |> expect(:list_devices, fn opts ->
      assert opts[:limit] == 10
      []
    end)

    {:ok, pid} = Server.start_link(interval: 200, backend_opts: [limit: 10])

    # Allow the server process to use the mock
    Mox.allow(Mock, self(), pid)

    # Allow the cleanup to run
    Process.sleep(300)
    assert Process.alive?(pid)
  end
end
