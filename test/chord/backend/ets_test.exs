defmodule Chord.Backend.ETSTest do
  use ExUnit.Case
  import TestHelpers
  alias Chord.Backend.ETS

  setup do
    Application.put_env(:chord, :time_provider, Chord.Utils.Time.Mock)
    # Ensure fresh ETS tables before each test
    :ets.new(:chord_context_table, [:named_table, :ordered_set, :public])
    :ets.new(:chord_context_history_table, [:named_table, :ordered_set, :public])
    {:ok, current_time: 1_673_253_120}
  end

  describe "Context operations" do
    test "set_context and get_context", %{current_time: current_time} do
      context_id = "game:1"
      context = %{score: 100}
      version = 1
      mock_time_expectation(unit: :second, time: current_time)
      {:ok, _context} = ETS.set_context(context_id, context, version)

      assert ETS.get_context(context_id) ==
               {:ok,
                %{
                  context_id: context_id,
                  context: context,
                  version: version,
                  inserted_at: current_time
                }}
    end

    test "delete_context", %{current_time: current_time} do
      context_id = "game:2"
      context = %{score: 50}
      version = 1

      mock_time_expectation([unit: :second, time: current_time], 2)

      {:ok, _context} = ETS.set_context(context_id, context, version)
      :ok = ETS.delete_context(context_id)

      assert ETS.get_context(context_id) == {:error, :not_found}
    end
  end

  describe "Delta operations" do
    test "set_delta and get_deltas for a context", %{current_time: current_time} do
      context_id = "game:1"
      old_version = 1
      new_version = 2
      old_delta = %{score: %{action: :added, value: 100}}
      new_delta = %{score: %{action: :modified, old_value: 100, value: 150}}

      mock_time_expectation([unit: :second, time: current_time], 2)

      {:ok, _delta} = ETS.set_delta(context_id, old_delta, old_version)
      {:ok, _delta} = ETS.set_delta(context_id, new_delta, new_version)

      assert ETS.get_deltas(context_id, old_version) ==
               {:ok,
                [
                  %{
                    context_id: context_id,
                    delta: new_delta,
                    version: new_version,
                    inserted_at: current_time
                  }
                ]}

      assert ETS.get_deltas(context_id, new_version) == {:error, :not_found}
    end

    test "delete_deltas_by_time removes deltas older than time", %{current_time: current_time} do
      context_id = "game:1"

      mock_time_expectation([unit: :second, time: current_time], 10)

      Enum.each(1..10, fn version ->
        delta = %{score: %{action: :added, value: version}}
        inserted_at = current_time - version
        :ets.insert(:chord_context_history_table, {{context_id, version}, delta, inserted_at})
      end)

      :ok = ETS.delete_deltas_by_time(context_id, current_time - 5)

      {:ok, remaining_deltas} = ETS.get_deltas(context_id, 0)
      assert Enum.count(remaining_deltas) == 5
    end

    test "delete_deltas_exceeding_threshold removes excess deltas", %{current_time: current_time} do
      context_id = "game:1"
      threshold = 5

      mock_time_expectation([unit: :second, time: current_time], 10)

      Enum.each(1..10, fn version ->
        delta = %{score: %{action: :added, value: version}}
        :ets.insert(:chord_context_history_table, {{context_id, version}, delta, current_time})
      end)

      :ok = ETS.delete_deltas_exceeding_threshold(context_id, threshold)

      {:ok, remaining_deltas} = ETS.get_deltas(context_id, 0)
      assert Enum.count(remaining_deltas) == threshold
    end
  end

  describe "Listing operations" do
    test "list_contexts returns all contexts with filters", %{current_time: current_time} do
      mock_time_expectation([unit: :second, time: current_time], 3)

      Enum.each(1..3, fn version ->
        context_id = "game:#{version}"
        context = %{score: version * 10}
        {:ok, _context} = ETS.set_context(context_id, context, version)
      end)

      {:ok, contexts} = ETS.list_contexts(limit: 2)
      assert length(contexts) == 2
    end

    test "list_deltas returns all deltas with filters", %{current_time: current_time} do
      mock_time_expectation([unit: :second, time: current_time], 3)

      Enum.each(1..3, fn version ->
        context_id = "game:1"
        delta = %{score: %{action: :added, value: version}}
        {:ok, _delta} = ETS.set_delta(context_id, delta, version)
      end)

      {:ok, deltas} = ETS.list_deltas(limit: 2)
      assert length(deltas) == 2
    end
  end
end
