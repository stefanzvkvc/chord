# Setup common data for benchmarking
defmodule BenchmarkHelpers do
  def prepare_context(context_id, context) do
    # Ensure the context exists before updates
    {:ok, _} = Chord.set_context(context_id, context)
  end

  def prepare_chat_room(context_id) do
    case Registry.lookup(Registry.ChatRoom, context_id) do
      [] -> ChatRoom.start_link(context_id)
      _ -> :ok
    end
  end

  def update_participant_status(context_id, participant_id, status) do
    Chord.update_context(context_id, %{
      participants: %{
        participant_id => %{status: status}
      }
    })
  end

  def update_typing_indicator(context_id, participant_id, typing) do
    Chord.update_context(context_id, %{
      participants: %{
        participant_id => %{typing: typing}
      }
    })
  end

  def sync_context(context_id, client_version) do
    Chord.sync_context(context_id, client_version)
  end

  def switch_to_redis_backend do
    Application.put_env(:chord, :backend, Chord.Backend.Redis)
    {:ok, _} = Redix.start_link(name: :redix, host: "localhost")
    Application.put_env(:chord, :redis_client, :redix)
  end

  def switch_to_ets_backend do
    Application.put_env(:chord, :backend, Chord.Backend.ETS)
  end

  def stop_redis_client do
    case Process.whereis(:redix) do
      nil -> :ok
      pid -> Process.exit(pid, :normal)
    end
  end

  def take_action(:stateless, action_index, context_id, participant_id, unique_value) do
    case rem(action_index, 3) do
      0 ->
        update_participant_status(
          context_id,
          participant_id,
          "active_#{unique_value}"
        )

      1 ->
        update_typing_indicator(
          context_id,
          participant_id,
          rem(unique_value, 2) == 0
        )

      2 ->
        sync_context(context_id, 1)
    end
  end

  def take_action(:stateful, action_index, context_id, participant_id, unique_value) do
    case rem(action_index, 3) do
      0 ->
        ChatRoom.update_status(context_id, participant_id, "active_#{unique_value}")

      1 ->
        ChatRoom.update_typing(context_id, participant_id, rem(unique_value, 2) == 0)

      2 ->
        ChatRoom.sync(context_id, 1)
    end
  end
end

defmodule ChatRoom do
  use GenServer

  def start_link(context_id),
    do: GenServer.start_link(__MODULE__, context_id, name: via_tuple(context_id))

  def init(context_id) do
    {:ok, %{context_id: context_id}}
  end

  def update_status(context_id, participant_id, status) do
    GenServer.call(via_tuple(context_id), {:update_status, participant_id, status})
  end

  def update_typing(context_id, participant_id, typing) do
    GenServer.call(via_tuple(context_id), {:update_typing, participant_id, typing})
  end

  def sync(context_id, client_version) do
    GenServer.call(via_tuple(context_id), {:sync, client_version})
  end

  def handle_call({:update_status, participant_id, status}, _from, state) do
    BenchmarkHelpers.update_participant_status(state.context_id, participant_id, status)
    {:reply, :ok, state}
  end

  def handle_call({:update_typing, participant_id, typing}, _from, state) do
    BenchmarkHelpers.update_typing_indicator(state.context_id, participant_id, typing)
    {:reply, :ok, state}
  end

  def handle_call({:sync, client_version}, _from, state) do
    result = BenchmarkHelpers.sync_context(state.context_id, client_version)
    {:reply, result, state}
  end

  defp via_tuple(context_id), do: {:via, Registry, {Registry.ChatRoom, context_id}}
end

# Ensure Registry is started
{:ok, _} = Registry.start_link(keys: :unique, name: Registry.ChatRoom)

# Define realistic data
large_context = fn group_id ->
  %{
    group_id: group_id,
    group_name: "Team Engineering #{group_id}",
    participants:
      Enum.into(1..50, %{}, fn i ->
        {
          "user_#{i}",
          %{
            user_id: "user_#{i}",
            username: "user_#{i}_name",
            avatar: "https://example.com/avatars/user_#{i}_name.png",
            status: if(rem(i, 3) == 0, do: "away", else: "active"),
            last_seen:
              DateTime.utc_now() |> DateTime.add(-i * 60, :second) |> DateTime.to_string(),
            typing: rem(i, 10) == 0
          }
        }
      end),
    metadata: %{
      topic: "Daily Standup #{group_id}",
      duration: "#{Enum.random(10..30)} minutes",
      created_by: "user_1",
      created_at: DateTime.utc_now() |> DateTime.add(-3600, :second) |> DateTime.to_string()
    },
    chat_history:
      Enum.into(1..20, [], fn i ->
        %{
          message_id: "msg_#{i}",
          sender_id: "user_#{rem(i, 50) + 1}",
          timestamp:
            DateTime.utc_now() |> DateTime.add(-i * 120, :second) |> DateTime.to_string(),
          content: "Message #{i}: Lorem ipsum dolor sit amet."
        }
      end)
  }
end

# Benchmark script
for backend <- [:ets, :redis] do
  case backend do
    :ets -> BenchmarkHelpers.switch_to_ets_backend()
    :redis -> BenchmarkHelpers.switch_to_redis_backend()
  end

  Benchee.run(
    %{
      "#{backend}: stateless - single context (50 participants)" => fn _ ->
        context_id = "group:123"
        context_data = large_context.(context_id)
        BenchmarkHelpers.prepare_context(context_id, context_data)

        1..50
        |> Enum.map(fn i ->
          unique_value = System.unique_integer([:positive])

          Task.async(fn ->
            participant_id = "user_#{rem(i, 50) + 1}"
            BenchmarkHelpers.take_action(:stateless, i, context_id, participant_id, unique_value)
          end)
        end)
        |> Task.yield_many(:infinity)
      end,
      "#{backend}: stateless - multiple contexts (100 contexts)" => fn _ ->
        Enum.map(1..100, fn id ->
          context_id = "group:#{id}"
          context_data = large_context.(context_id)
          BenchmarkHelpers.prepare_context(context_id, context_data)
        end)

        # Generate tasks for multiple actions
        1..100
        |> Enum.flat_map(fn id ->
          context_id = "group:#{id}"

          Enum.map(1..10, fn action_index ->
            Task.async(fn ->
              participant_id = "user_#{Enum.random(1..50)}"
              unique_value = System.unique_integer([:positive])

              BenchmarkHelpers.take_action(
                :stateless,
                action_index,
                context_id,
                participant_id,
                unique_value
              )
            end)
          end)
        end)
        |> Task.yield_many(:infinity)
      end,
      "#{backend}: stateful - single context (50 participants)" => fn _ ->
        context_id = "group:stateful_123"
        context_data = large_context.(context_id)
        BenchmarkHelpers.prepare_context(context_id, context_data)
        BenchmarkHelpers.prepare_chat_room(context_id)

        1..50
        |> Enum.map(fn i ->
          unique_value = System.unique_integer([:positive])

          Task.async(fn ->
            participant_id = "user_#{rem(i, 50) + 1}"
            BenchmarkHelpers.take_action(:stateful, i, context_id, participant_id, unique_value)
          end)
        end)
        |> Task.yield_many(:infinity)
      end,
      "#{backend}: stateful - multiple contexts (100 contexts)" => fn _ ->
        Enum.map(1..100, fn id ->
          context_id = "group:#{id}"
          context_data = large_context.(context_id)
          BenchmarkHelpers.prepare_context(context_id, context_data)
          BenchmarkHelpers.prepare_chat_room(context_id)
        end)

        # Generate tasks for multiple actions
        1..100
        |> Enum.flat_map(fn id ->
          context_id = "group:#{id}"

          Enum.map(1..10, fn action_index ->
            Task.async(fn ->
              participant_id = "user_#{Enum.random(1..50)}"
              unique_value = System.unique_integer([:positive])

              BenchmarkHelpers.take_action(
                :stateful,
                action_index,
                context_id,
                participant_id,
                unique_value
              )
            end)
          end)
        end)
        |> Task.yield_many(:infinity)
      end
    },
    inputs: %{
      "Data" => large_context.(1)
    },
    formatters: [
      Benchee.Formatters.Console
    ]
  )

  if backend == :redis, do: BenchmarkHelpers.stop_redis_client()
end
