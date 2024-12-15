defmodule Knot.CleanupTest do
  use ExUnit.Case, async: true
  import TestHelpers
  alias Knot.Cleanup

  setup do
    Application.put_env(:knot, :backend, Knot.Backend.Mock)
    Application.put_env(:knot, :time, Knot.Utils.Time.Mock)
    Application.put_env(:knot, :context_ttl, :timer.hours(6))
    Application.put_env(:knot, :context_auto_delete, false)
    Application.put_env(:knot, :delta_ttl, :timer.hours(3))

    {:ok, current_time: 1_673_253_120}
  end

  describe "Context cleanup" do
    test "does nothing when auto deletion is off and no deltas available", %{
      current_time: current_time
    } do
      Application.put_env(:knot, :context_auto_delete, false)

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_deltas_expectation([])
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end

    test "cleans up inactive contexts based on TTL", %{
      current_time: current_time
    } do
      Application.put_env(:knot, :context_auto_delete, true)
      context_id = "game:1"
      context_ttl = Application.get_env(:knot, :context_ttl)
      context_time = current_time - context_ttl - 1

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_contexts_expectation(context_id: context_id, inserted_at: context_time)
      mock_delete_context_expectation(context_id: context_id)
      mock_delete_deltas_for_context_expectation(context_id: context_id)
      mock_list_deltas_expectation([])
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end

    test "does not delete active contexts", %{
      current_time: current_time
    } do
      Application.put_env(:knot, :context_auto_delete, true)
      context_id = "game:1"
      context_ttl = Application.get_env(:knot, :context_ttl)
      delta_ttl = Application.get_env(:knot, :delta_ttl)
      active_context_time = current_time - context_ttl + 100
      active_delta_time = current_time - delta_ttl + 100

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_contexts_expectation(context_id: context_id, inserted_at: active_context_time)
      mock_list_deltas_expectation(context_id: context_id, inserted_at: active_delta_time)
      mock_list_contexts_with_delta_counts_expectation([])
    end

    test "handles empty contexts gracefully", %{
      current_time: current_time
    } do
      mock_time_expectation(unit: :second, time: current_time)
      mock_list_contexts_expectation([])
      mock_list_deltas_expectation([])
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end
  end

  describe "Delta cleanup" do
    test "cleans up deltas based on TTL", %{current_time: current_time} do
      context_id = "game:1"
      delta_ttl = Application.get_env(:knot, :delta_ttl)
      delta_time = current_time - delta_ttl - 1
      older_than_time = current_time - delta_ttl

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_deltas_expectation(context_id: context_id, inserted_at: delta_time)
      mock_delete_deltas_by_time(context_id: context_id, older_than_time: older_than_time)
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end

    test "removes deltas exceeding the threshold", %{
      current_time: current_time
    } do
      context_id = "game:1"
      delta_threshold = Application.get_env(:knot, :delta_threshold)

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_deltas_expectation([])
      mock_list_contexts_with_delta_counts_expectation([%{context_id: context_id, count: delta_threshold + 10}])
      mock_delete_deltas_exceeding_threshold(context_id: context_id, threshold: delta_threshold)

      Cleanup.periodic_cleanup()
    end

    test "does not delete active deltas", %{
      current_time: current_time
    } do
      context_id = "game:1"
      delta_ttl = Application.get_env(:knot, :delta_ttl)
      active_delta_time = current_time - delta_ttl + 100

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_deltas_expectation(context_id: context_id, inserted_at: active_delta_time)
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end

    test "handles empty deltas gracefully", %{
      current_time: current_time
    } do
      mock_time_expectation(unit: :second, time: current_time)
      mock_list_deltas_expectation([])
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end
  end

  describe "Boundary and concurrency handling" do
    test "handles boundary TTL values correctly", %{current_time: current_time} do
      context_id = "game:1"
      context_ttl = Application.get_env(:knot, :context_ttl)
      delta_ttl = Application.get_env(:knot, :delta_ttl)

      # Times set just outside the TTL boundary
      context_boundary_time = current_time - context_ttl - 1
      exact_delta_threshold = current_time - delta_ttl

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_contexts_expectation(context_id: context_id, inserted_at: context_boundary_time)
      mock_delete_context_expectation(context_id: context_id)
      mock_list_deltas_expectation(context_id: context_id, inserted_at: exact_delta_threshold - 1)
      mock_delete_deltas_by_time(context_id: context_id, older_than_time: exact_delta_threshold)
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end
  end

  test "handles concurrent periodic cleanup calls", %{current_time: current_time} do
    context_id = "game:1"
    context_ttl = Application.get_env(:knot, :context_ttl)
    delta_ttl = Application.get_env(:knot, :delta_ttl)
    older_than_time = current_time - delta_ttl
    context_time = current_time - context_ttl - 1
    delta_time = current_time - delta_ttl - 1

    mock_time_expectation([unit: :second, time: current_time], 5)
    mock_list_contexts_expectation([context_id: context_id, inserted_at: context_time], 5)
    mock_delete_context_expectation([context_id: context_id], 5)
    mock_list_deltas_expectation([context_id: context_id, inserted_at: delta_time], 5)
    mock_delete_deltas_by_time([context_id: context_id, older_than_time: older_than_time], 5)
    mock_list_contexts_with_delta_counts_expectation([], 5)

    tasks =
      Enum.map(1..5, fn _ ->
        Task.async(fn -> Cleanup.periodic_cleanup() end)
      end)

    Enum.each(tasks, &Task.await/1)
  end
end
