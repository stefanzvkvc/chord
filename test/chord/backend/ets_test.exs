defmodule Chord.Backend.ETSTest do
  use ExUnit.Case
  import Chord.Support.MocksHelpers.Time
  alias Chord.Backend.ETS

  setup do
    Application.put_env(:chord, :time_provider, Chord.Support.Mocks.Time)
    # Ensure fresh ETS tables before each test
    :ets.new(:chord_context_table, [:named_table, :ordered_set, :public])
    :ets.new(:chord_context_history_table, [:named_table, :ordered_set, :public])

    current_time = 1_737_888_978
    context_id = "test-context"
    context = %{score: 0}
    delta = %{score: %{action: :added, value: 100}}
    version = 1

    expected_context_result = %{
      context_id: context_id,
      context: context,
      version: version,
      inserted_at: current_time
    }

    expected_delta_result = %{
      context_id: context_id,
      delta: delta,
      version: version,
      inserted_at: current_time
    }

    {:ok,
     current_time: current_time,
     context_id: context_id,
     context: context,
     version: version,
     delta: delta,
     expected_context_result: expected_context_result,
     expected_delta_result: expected_delta_result}
  end

  describe "Context operations" do
    test "set_context", %{
      current_time: current_time,
      context_id: context_id,
      context: context,
      version: version,
      expected_context_result: expected_context_result
    } do
      mock_time(time: current_time)
      {:ok, result} = ETS.set_context(context_id, context, version)
      assert result == expected_context_result
    end

    test "get_context", %{
      current_time: current_time,
      context_id: context_id,
      context: context,
      version: version,
      expected_context_result: expected_context_result
    } do
      mock_time(time: current_time)
      {:ok, result_1} = ETS.set_context(context_id, context, version)
      {:ok, result_2} = ETS.get_context(context_id)
      assert result_1 == expected_context_result
      assert result_2 == expected_context_result
    end

    test "context is not found", %{
      context_id: context_id
    } do
      assert {:error, :not_found} = ETS.get_context(context_id)
    end

    test "delete_context", %{
      current_time: current_time,
      context_id: context_id,
      context: context,
      version: version,
      expected_context_result: expected_context_result
    } do
      mock_time([time: current_time], 2)

      {:ok, result} = ETS.set_context(context_id, context, version)
      :ok = ETS.delete_context(context_id)

      assert result == expected_context_result
      assert {:error, :not_found} = ETS.get_context(context_id)
    end
  end

  describe "Delta operations" do
    test "set_delta for a context", %{
      current_time: current_time,
      context_id: context_id,
      version: version,
      delta: delta,
      expected_delta_result: expected_delta_result
    } do
      mock_time(time: current_time)

      {:ok, result} = ETS.set_delta(context_id, delta, version)
      assert result == expected_delta_result
    end

    test "get_deltas for a context", %{
      current_time: current_time,
      context_id: context_id,
      version: version,
      delta: delta,
      expected_delta_result: expected_delta_result
    } do
      mock_time(time: current_time)
      {:ok, result_1} = ETS.set_delta(context_id, delta, version)
      {:ok, [result_2]} = ETS.get_deltas(context_id, 0)
      assert result_1 == expected_delta_result
      assert result_2 == expected_delta_result
    end

    test "deltas not found for a context", %{context_id: context_id} do
      assert ETS.get_deltas(context_id, 0) == {:error, :not_found}
    end

    test "delete_deltas_by_time removes deltas older than time", %{
      current_time: current_time,
      context_id: context_id,
      delta: delta
    } do
      mock_time([time: current_time], 10)

      Enum.each(1..10, fn version ->
        delta = put_in(delta, [:score, :value], version)
        inserted_at = current_time - version
        :ets.insert(:chord_context_history_table, {{context_id, version}, delta, inserted_at})
      end)

      :ok = ETS.delete_deltas_by_time(context_id, current_time - 5)

      {:ok, remaining_deltas} = ETS.get_deltas(context_id, 0)
      assert Enum.count(remaining_deltas) == 5
    end

    test "delete_deltas_exceeding_threshold removes excess deltas", %{
      current_time: current_time,
      context_id: context_id,
      delta: delta
    } do
      threshold = 5

      mock_time([time: current_time], 10)

      Enum.each(1..10, fn version ->
        delta = put_in(delta, [:score, :value], version)
        :ets.insert(:chord_context_history_table, {{context_id, version}, delta, current_time})
      end)

      :ok = ETS.delete_deltas_exceeding_threshold(context_id, threshold)

      {:ok, remaining_deltas} = ETS.get_deltas(context_id, 0)
      assert Enum.count(remaining_deltas) == threshold
    end
  end

  describe "Listing operations" do
    test "list_contexts returns all contexts with filters", %{
      current_time: current_time,
      context: context
    } do
      mock_time([time: current_time], 3)

      Enum.each(1..3, fn version ->
        context_id = "game:#{version}"
        context = Map.update(context, :score, 0, &(&1 * 2))

        {:ok, _context} = ETS.set_context(context_id, context, version)
      end)

      {:ok, contexts} = ETS.list_contexts(limit: 2)
      assert length(contexts) == 2
    end

    test "list_deltas returns all deltas with filters", %{
      current_time: current_time,
      context_id: context_id,
      delta: delta
    } do
      mock_time([time: current_time], 3)

      Enum.each(1..3, fn version ->
        delta = put_in(delta, [:score, :value], version)
        {:ok, _delta} = ETS.set_delta(context_id, delta, version)
      end)

      {:ok, deltas} = ETS.list_deltas(limit: 2)
      assert length(deltas) == 2
    end
  end
end
