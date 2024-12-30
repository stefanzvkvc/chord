# Setup common data for benchmarking
small_context = %{status: "active"}
large_context = Enum.into(1..100, %{}, fn i -> {"key_#{i}", "value_#{i}"} end)

# Ensure Registry is started
{:ok, _} = Registry.start_link(keys: :unique, name: Registry.ChatRoom)

# Define ChatRoom GenServer
defmodule ChatRoom do
  use GenServer

  def start_link(context_id) do
    GenServer.start_link(__MODULE__, context_id, name: via_tuple(context_id))
  end

  def send_message(context_id, user, message) do
    GenServer.call(via_tuple(context_id), {:send_message, user, message})
  end

  def get_context(context_id) do
    GenServer.call(via_tuple(context_id), :get_context)
  end

  def init(context_id) do
    {:ok, %{context_id: context_id, messages: []}}
  end

  def handle_call({:send_message, user, message}, _from, state) do
    updated_context = %{messages: state.messages ++ [%{user: user, message: message}]}
    {:ok, _} = Chord.update_context(state.context_id, updated_context)
    {:reply, :ok, %{state | messages: updated_context.messages}}
  end

  def handle_call(:get_context, _from, state) do
    case Chord.get_context(state.context_id) do
      {:ok, context} -> {:reply, context, state}
      {:error, _} -> {:reply, nil, state}
    end
  end

  defp via_tuple(context_id), do: {:via, Registry, {Registry.ChatRoom, context_id}}
end

# Helper module for setup
defmodule BenchmarkHelpers do
  def prepare_context(context_id, initial_data) do
    {:ok, _} = Chord.set_context(context_id, initial_data)
  end

  def prepare_chat_room(context_id) do
    case Registry.lookup(Registry.ChatRoom, context_id) do
      [] ->
        {:ok, _pid} = ChatRoom.start_link(context_id)
        :ok

      _ ->
        :ok
    end
  end

  def switch_to_redis_backend do
    Application.put_env(:chord, :backend, Chord.Backend.Redis)
    # Start a Redix connection process
    {:ok, _pid} = Redix.start_link(name: :redix_benchmark, host: "localhost", port: 6379)
    Application.put_env(:chord, :redis_client, :redix_benchmark)
  end

  def stop_redis_connection do
    # Stop the Redix connection process
    case Process.whereis(:redix_benchmark) do
      nil -> :ok
      pid -> Process.exit(pid, :normal)
    end
  end

  def switch_to_ets_backend do
    Application.put_env(:chord, :backend, Chord.Backend.ETS)
  end
end

# Run benchmarks for both ETS and Redis backends
for backend <- [:ets, :redis] do
  case backend do
    :ets -> BenchmarkHelpers.switch_to_ets_backend()
    :redis -> BenchmarkHelpers.switch_to_redis_backend()
  end

  Benchee.run(
    %{
      # Stateless Benchmark: Direct Library Calls
      "#{backend}: stateless - single context (50 participants)" => fn _ ->
        context_id = "group:123"
        BenchmarkHelpers.prepare_context(context_id, small_context)

        Enum.map(1..50, fn i ->
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
        |> Task.yield_many(:infinity)
      end,
      "#{backend}: stateless - multiple contexts (100 contexts)" => fn _ ->
        Enum.map(1..100, fn id ->
          context_id = "group:#{id}"
          BenchmarkHelpers.prepare_context(context_id, small_context)

          Task.async(fn ->
            unique_value = System.unique_integer([:positive])

            case rem(id, 3) do
              0 -> Chord.set_context(context_id, %{status: "active_#{unique_value}"})
              1 -> Chord.update_context(context_id, %{status: "inactive_#{unique_value}"})
              2 -> Chord.sync_context(context_id, 1)
            end
          end)
        end)
        |> Task.yield_many(:infinity)
      end,

      # Stateful Benchmark: GenServer Per Context
      "#{backend}: stateful - single context (50 participants)" => fn _ ->
        context_id = "group:123"
        BenchmarkHelpers.prepare_context(context_id, small_context)
        :ok = BenchmarkHelpers.prepare_chat_room(context_id)

        Enum.map(1..50, fn i ->
          unique_value = System.unique_integer([:positive])

          Task.async(fn ->
            case rem(i, 3) do
              0 ->
                ChatRoom.send_message(
                  context_id,
                  "participant_#{i}",
                  "message_#{unique_value}"
                )

              1 ->
                ChatRoom.send_message(
                  context_id,
                  "participant_#{i}",
                  "update_message_#{unique_value}"
                )

              2 ->
                ChatRoom.get_context(context_id)
            end
          end)
        end)
        |> Task.yield_many(:infinity)
      end,
      "#{backend}: stateful - multiple contexts (100 contexts)" => fn _ ->
        Enum.map(1..100, fn id ->
          context_id = "group:#{id}"
          BenchmarkHelpers.prepare_context(context_id, small_context)
          :ok = BenchmarkHelpers.prepare_chat_room(context_id)

          Task.async(fn ->
            unique_value = System.unique_integer([:positive])

            case rem(id, 3) do
              0 ->
                ChatRoom.send_message(
                  context_id,
                  "participant_#{id}",
                  "message_#{unique_value}"
                )

              1 ->
                ChatRoom.send_message(
                  context_id,
                  "participant_#{id}",
                  "update_message_#{unique_value}"
                )

              2 ->
                ChatRoom.get_context(context_id)
            end
          end)
        end)
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

  if backend == :redis do
    BenchmarkHelpers.stop_redis_connection()
  end
end
