# bench/chord_benchmark.exs

# Setup common data for benchmarking
small_context = %{status: "active"}
large_context = Enum.into(1..100, %{}, fn i -> {"key_#{i}", "value_#{i}"} end)

# Helper function to initialize the context
defmodule BenchmarkHelpers do
  def prepare_context(context_id, initial_data) do
    {:ok, _} = Chord.set_context(context_id, initial_data)
  end
end

Benchee.run(
  %{
    # Benchmark single context with mixed operations (e.g., a group chat or video meeting)
    "single context - mixed operations (50 participants)" => fn _ ->
      context_id = "meeting:123"
      BenchmarkHelpers.prepare_context(context_id, small_context)

      # Spawn 50 participants interacting with the same context
      1..50
      |> Enum.map(fn i ->
        unique_value = System.unique_integer([:positive])

        Task.async(fn ->
          case rem(i, 3) do
            0 ->
              Chord.set_context(context_id, %{"participant_#{i}" => "status_#{unique_value}"})

            1 ->
              Chord.update_context(context_id, %{
                "participant_#{i}" => "updated_status_#{unique_value}"
              })

            2 ->
              Chord.sync_context(context_id, 1)
          end
        end)
      end)
      # Ensure all tasks complete
      |> Task.yield_many(:infinity)
    end,

    # Benchmark multiple contexts with mixed operations (e.g., multiple group chats)
    "multiple contexts - mixed operations (100 contexts)" => fn _ ->
      # Initialize contexts
      1..100
      |> Enum.each(fn id ->
        context_id = "group:#{id}"
        BenchmarkHelpers.prepare_context(context_id, small_context)
      end)

      # Spawn tasks for 100 different contexts
      1..100
      |> Enum.map(fn id ->
        context_id = "group:#{id}"
        unique_value = System.unique_integer([:positive])

        Task.async(fn ->
          case rem(id, 3) do
            0 -> Chord.set_context(context_id, %{status: "active_#{unique_value}"})
            1 -> Chord.update_context(context_id, %{status: "inactive_#{unique_value}"})
            2 -> Chord.sync_context(context_id, 1)
          end
        end)
      end)
      # Ensure all tasks complete
      |> Task.yield_many(:infinity)
    end
  },
  inputs: %{
    "Small Data" => small_context,
    "Large Data" => large_context
  },
  formatters: [
    Benchee.Formatters.Console
  ]
)
