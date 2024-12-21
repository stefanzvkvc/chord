defmodule Chord.CleanupTest do
  use ExUnit.Case, async: true
  import TestHelpers
  alias Chord.Cleanup

  setup do
    Application.put_env(:chord, :backend, Chord.Backend.Mock)
    Application.put_env(:chord, :time_provider, Chord.Utils.Time.Mock)
    Application.put_env(:chord, :context_ttl, :timer.hours(6))
    Application.put_env(:chord, :context_auto_delete, false)
    Application.put_env(:chord, :delta_ttl, :timer.hours(3))
    Application.put_env(:chord, :delta_threshold, 100)

    {:ok, current_time: 1_673_253_120}
  end

  describe "Context cleanup" do
    test "does nothing when auto deletion is off and no deltas available", %{
      current_time: current_time
    } do
      Application.put_env(:chord, :context_auto_delete, false)

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_deltas_expectation([])
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end

    test "cleans up inactive contexts based on TTL", %{
      current_time: current_time
    } do
      Application.put_env(:chord, :context_auto_delete, true)
      context_id = "game:1"
      context = %{name: "Alice", status: "online"}
      context_ttl = Application.get_env(:chord, :context_ttl)
      context_time = current_time - context_ttl - 1

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_contexts_expectation(context_id: context_id, inserted_at: context_time)
      mock_get_context_expectation(context_id: context_id, context: context, version: 1)
      mock_delete_context_expectation(context_id: context_id)
      mock_delete_deltas_for_context_expectation(context_id: context_id)
      mock_list_deltas_expectation([])
      mock_list_contexts_with_delta_counts_expectation([])

      Cleanup.periodic_cleanup()
    end

    test "does not delete active contexts", %{
      current_time: current_time
    } do
      Application.put_env(:chord, :context_auto_delete, true)
      context_id = "game:1"
      context_ttl = Application.get_env(:chord, :context_ttl)
      active_context_time = current_time - context_ttl + 100

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_contexts_expectation(context_id: context_id, inserted_at: active_context_time)
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
      delta_ttl = Application.get_env(:chord, :delta_ttl)
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
      delta_threshold = Application.get_env(:chord, :delta_threshold)

      mock_time_expectation(unit: :second, time: current_time)
      mock_list_deltas_expectation([])

      mock_list_contexts_with_delta_counts_expectation([
        %{context_id: context_id, count: delta_threshold + 10}
      ])

      mock_delete_deltas_exceeding_threshold(context_id: context_id, threshold: delta_threshold)

      Cleanup.periodic_cleanup()
    end

    test "does not delete active deltas", %{
      current_time: current_time
    } do
      context_id = "game:1"
      delta_ttl = Application.get_env(:chord, :delta_ttl)
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

  test "handles concurrent periodic cleanup calls", %{current_time: current_time} do
    context_id = "game:1"
    context_ttl = Application.get_env(:chord, :context_ttl)
    delta_ttl = Application.get_env(:chord, :delta_ttl)
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
