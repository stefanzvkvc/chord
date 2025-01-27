defmodule Chord.Cleanup.ServerTest do
  use ExUnit.Case, async: true
  import Chord.Support.MocksHelpers.Backend
  import Chord.Support.MocksHelpers.Time
  alias Chord.Cleanup.Server

  setup do
    Application.put_env(:chord, :backend, Chord.Support.Mocks.Backend)
    Application.put_env(:chord, :time_provider, Chord.Support.Mocks.Time)
    Application.put_env(:chord, :context_ttl, :timer.hours(6))
    Application.put_env(:chord, :context_auto_delete, false)
    Application.put_env(:chord, :delta_ttl, :timer.hours(3))

    {:ok, current_time: 1_737_888_978}
  end

  describe "Periodic Cleanup Execution" do
    test "triggers periodic cleanup", %{current_time: current_time} do
      unique_name = get_process_name()
      context_id = "game:1"
      context_ttl = Application.get_env(:chord, :context_ttl)
      delta_ttl = Application.get_env(:chord, :delta_ttl)
      context_time = current_time - context_ttl - 1
      delta_threshold = current_time - delta_ttl

      mock_time(time: current_time)
      mock_list_contexts(context_id: context_id, inserted_at: context_time)
      mock_delete_context(context_id: context_id)
      mock_list_deltas(context_id: context_id, inserted_at: delta_threshold - 1)
      mock_delete_deltas_by_time(context_id: context_id, older_than_time: delta_threshold)
      mock_list_contexts_with_delta_counts([])

      {:ok, pid} = Server.start_link(name: unique_name, interval: 200, backend_opts: [])
      Mox.allow(Chord.Support.Mocks.Time, self(), pid)
      Mox.allow(Chord.Support.Mocks.Backend, self(), pid)

      Process.sleep(300)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "Backend Configuration" do
    test "uses backend_opts for periodic cleanup", %{current_time: current_time} do
      unique_name = get_process_name()
      mock_time(time: current_time)
      mock_list_contexts(limit: 10)
      mock_list_deltas(limit: 10)
      mock_list_contexts_with_delta_counts([])

      {:ok, pid} = Server.start_link(name: unique_name, interval: 200, backend_opts: [limit: 10])
      Mox.allow(Chord.Support.Mocks.Time, self(), pid)
      Mox.allow(Chord.Support.Mocks.Backend, self(), pid)

      Process.sleep(300)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "Dynamic Updates" do
    test "updates interval dynamically" do
      unique_name = get_process_name()
      {:ok, pid} = Server.start_link(name: unique_name, interval: 200, backend_opts: [])
      assert Server.update_interval(1000, unique_name) == :ok
      state = :sys.get_state(pid)
      assert state.interval == 1000
      GenServer.stop(pid)
    end

    test "updates backend options dynamically" do
      unique_name = get_process_name()
      {:ok, pid} = Server.start_link(name: unique_name, interval: 200, backend_opts: [limit: 10])
      assert Server.update_backend_opts([limit: 20], unique_name) == :ok
      state = :sys.get_state(pid)
      assert state.backend_opts == [limit: 20]
      GenServer.stop(pid)
    end
  end

  describe "Robustness" do
    test "handles unexpected messages" do
      unique_name = get_process_name()
      {:ok, pid} = Server.start_link(name: unique_name, interval: 200, backend_opts: [])
      send(pid, :unexpected_message)
      Process.sleep(50)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  defp get_process_name() do
    :"cleanup_server_#{:erlang.unique_integer()}"
  end
end
