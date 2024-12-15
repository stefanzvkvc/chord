defmodule Knot.Cleanup.ServerTest do
  use ExUnit.Case, async: true
  import TestHelpers
  alias Knot.Cleanup.Server

  setup do
    Application.put_env(:knot, :backend, Knot.Backend.Mock)
    Application.put_env(:knot, :time, Knot.Utils.Time.Mock)
    Application.put_env(:knot, :context_ttl, :timer.hours(6))
    Application.put_env(:knot, :context_auto_delete, false)
    Application.put_env(:knot, :delta_ttl, :timer.hours(3))

    on_exit(fn ->
      case Process.whereis(Knot.Cleanup.Server) do
        nil -> :ok
        pid -> GenServer.stop(pid, :normal)
      end
    end)

    {:ok, current_time: 1_673_253_120}
  end

  describe "Initialization and Shutdown" do
    test "server initializes and runs" do
      {:ok, pid} = Server.start_link(interval: 200, backend_opts: [])

      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "server shuts down gracefully" do
      {:ok, pid} = Server.start_link(interval: 200, backend_opts: [])
      assert Process.alive?(pid)

      GenServer.stop(pid)
      refute Process.alive?(pid)
    end
  end

  describe "Periodic Cleanup Execution" do
    test "triggers periodic cleanup", %{current_time: current_time} do
      context_id = "game:1"
      context_ttl = Application.get_env(:knot, :context_ttl)
      delta_ttl = Application.get_env(:knot, :delta_ttl)
      context_time = current_time - context_ttl - 1
      delta_threshold = current_time - delta_ttl

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_contexts_expectation(context_id: context_id, inserted_at: context_time)
      mock_delete_context_expectation(context_id: context_id)
      mock_list_deltas_expectation(context_id: context_id, inserted_at: delta_threshold - 1)
      mock_delete_deltas_by_time(context_id: context_id, older_than_time: delta_threshold)
      mock_list_contexts_with_delta_counts_expectation([])

      {:ok, pid} = Server.start_link(interval: 200, backend_opts: [])
      allow_sharing_expectation(Knot.Utils.Time.Mock, self(), pid)
      allow_sharing_expectation(Knot.Backend.Mock, self(), pid)

      Process.sleep(300)

      assert Process.alive?(pid)
    end

    # test "reschedules cleanup after execution", %{current_time: current_time} do
    #   context_id = "game:1"
    #   context_ttl = Application.get_env(:knot, :context_ttl)
    #   delta_ttl = Application.get_env(:knot, :delta_ttl)
    #   context_time = current_time - context_ttl - 1
    #   delta_threshold = current_time - delta_ttl

    #   mock_time_expectation(unit: :second, time: current_time)
    #   mock_list_contexts_expectation(context_id: context_id, inserted_at: context_time)
    #   mock_delete_context_expectation(context_id: context_id)
    #   mock_list_deltas_expectation(context_id: context_id, inserted_at: delta_threshold - 1)
    #   mock_delete_deltas_by_time(context_id: context_id, older_than_time: delta_threshold)
    #   mock_list_contexts_with_delta_counts_expectation([])

    #   {:ok, pid} = Server.start_link(interval: 100, backend_opts: [])
    #   allow_sharing_expectation(Knot.Utils.Time.Mock, self(), pid)
    #   allow_sharing_expectation(Knot.Backend.Mock, self(), pid)

    #   Process.sleep(150)

    #   assert Process.alive?(pid)
    # end
  end

  describe "Backend Configuration" do
    test "uses backend_opts for periodic cleanup", %{current_time: current_time} do
      mock_time_expectation(unit: :second, time: current_time)
      mock_list_contexts_expectation(limit: 10)
      mock_list_deltas_expectation(limit: 10)
      mock_list_contexts_with_delta_counts_expectation([])


      {:ok, pid} = Server.start_link(interval: 200, backend_opts: [limit: 10])
      allow_sharing_expectation(Knot.Utils.Time.Mock, self(), pid)
      allow_sharing_expectation(Knot.Backend.Mock, self(), pid)

      Process.sleep(300)

      assert Process.alive?(pid)
    end
  end

  describe "Robustness" do
    test "handles unexpected messages" do
      {:ok, pid} = Server.start_link(interval: 200, backend_opts: [])

      send(pid, :unexpected_message)
      Process.sleep(50)

      assert Process.alive?(pid)
    end
  end

  describe "Dynamic Updates" do
    test "updates interval dynamically" do
      {:ok, pid} = Server.start_link(interval: 200, backend_opts: [])

      assert Server.update_interval(300) == :ok
      state = :sys.get_state(pid)
      assert state.interval == 300
    end

    test "updates backend options dynamically" do
      {:ok, pid} = Server.start_link(interval: 200, backend_opts: [limit: 10])

      assert Server.update_backend_opts(limit: 20) == :ok
      state = :sys.get_state(pid)
      assert state.backend_opts == [limit: 20]
    end
  end
end
