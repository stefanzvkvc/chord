defmodule Chord.Backend.RedisTest do
  use ExUnit.Case, async: true
  import Chord.Support.MocksHelpers.Redis
  import Chord.Support.MocksHelpers.Time
  alias Chord.Backend.Redis

  setup do
    Application.put_env(:chord, :redis_client, Chord.Support.Mocks.Redis)
    Application.put_env(:chord, :time_provider, Chord.Support.Mocks.Time)
    current_time = 1_673_253_120
    context_id = "test-context"
    context = %{score: 0}
    delta = %{score: %{action: :added, value: 100}}
    version = 1
    client_version = 0

    expected_context_response = %{
      context_id: context_id,
      context: context,
      version: version,
      inserted_at: current_time
    }

    expected_delta_response = %{
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
     client_version: client_version,
     expected_context_response: expected_context_response,
     expected_delta_response: expected_delta_response}
  end

  describe "Context Operations" do
    test "set_context", %{
      current_time: current_time,
      context_id: context_id,
      context: context,
      version: version,
      expected_context_response: expected_context_response
    } do
      mock_time(unit: :second, time: current_time)
      mock_hset(context_id: context_id)
      {:ok, result} = Redis.set_context(context_id, context, version)
      assert result == expected_context_response
    end

    test "get_context", %{
      current_time: current_time,
      context_id: context_id,
      context: context,
      version: version,
      expected_context_response: expected_context_response
    } do
      mock_time(unit: :second, time: current_time)
      mock_hset(context_id: context_id)

      mock_hgetall(
        context_id: context_id,
        context: context,
        version: version,
        inserted_at: current_time
      )

      {:ok, result_1} = Redis.set_context(context_id, context, version)
      {:ok, result_2} = Redis.get_context(context_id)
      assert result_1 == expected_context_response
      assert result_2 == expected_context_response
    end

    test "returns :not_found for missing context", %{context_id: context_id} do
      mock_hgetall([])

      assert {:error, :not_found} = Redis.get_context(context_id)
    end

    test "deletes a context", %{context_id: context_id} do
      mock_hdel(context_id: context_id)

      assert :ok = Redis.delete_context(context_id)
    end
  end

  describe "Deltas Operations" do
    test "set_delta for a context", %{
      current_time: current_time,
      context_id: context_id,
      version: version,
      delta: delta,
      expected_delta_response: expected_delta_response
    } do
      mock_time(unit: :second, time: current_time)

      mock_zadd(
        context_id: context_id,
        delta: delta,
        version: version,
        inserted_at: current_time
      )

      {:ok, result} = Redis.set_delta(context_id, delta, version)
      assert result == expected_delta_response
    end

    test "get_deltas for a context", %{
      current_time: current_time,
      context_id: context_id,
      delta: delta,
      expected_delta_response: expected_delta_response,
      version: version,
      client_version: client_version
    } do
      mock_time(unit: :second, time: current_time)

      mock_zadd(
        context_id: context_id,
        delta: delta,
        version: version,
        inserted_at: current_time
      )

      mock_zrangebyscore(
        context_id: context_id,
        client_version: client_version,
        delta: delta,
        version: version,
        inserted_at: current_time
      )

      {:ok, result_1} = Redis.set_delta(context_id, delta, version)
      {:ok, [result_2]} = Redis.get_deltas(context_id, 0)
      assert result_1 == expected_delta_response
      assert result_2 == expected_delta_response
    end

    test "returns :not_found if no deltas exist" do
      context_id = "test-context"
      version = 1
      mock_zrangebyscore([])

      assert {:error, :not_found} = Redis.get_deltas(context_id, version)
    end

    test "deletes all deltas for a context" do
      context_id = "test-context"
      mock_del(context_id: context_id)

      assert :ok = Redis.delete_deltas_for_context(context_id)
    end

    test "deletes deltas older than a specific time", %{current_time: current_time} do
      context_id = "test-context"
      older_than_time = current_time - 5
      mock_zremrangebyscore(context_id: context_id, older_than_time: older_than_time)

      assert :ok = Redis.delete_deltas_by_time(context_id, older_than_time)
    end

    test "deletes excess deltas" do
      context_id = "test-context"
      delta_trashold = 5
      number_of_elements = 10
      rank_limit = 4
      mock_zcard(context_id: context_id, count: number_of_elements)
      mock_zremrangebyrank(context_id: context_id, rank_limit: rank_limit)

      assert :ok = Redis.delete_deltas_exceeding_threshold(context_id, delta_trashold)
    end
  end

  describe "Listing operations" do
    test "lists contexts with filters applied", %{
      current_time: current_time,
      context: context,
      version: version
    } do
      pattern = "chord:context:*"
      keys = ["chord:context:1", "chord:context:2"]
      mock_keys(pattern: pattern, keys: keys)

      for key <- keys do
        context_id = key |> String.split(":") |> List.last()

        mock_hgetall(
          context_id: context_id,
          context: context,
          version: version,
          inserted_at: current_time
        )
      end

      {:ok, contexts} = Redis.list_contexts([])
      assert length(contexts) == 2
    end

    test "lists deltas", %{
      delta: delta,
      version: version,
      client_version: client_version
    } do
      pattern = "chord:delta:*"
      keys = ["chord:delta:1", "chord:delta:2"]
      mock_keys(pattern: pattern, keys: keys)

      for key <- keys do
        context_id = key |> String.split(":") |> List.last()

        mock_zrangebyscore(
          context_id: context_id,
          client_version: client_version,
          delta: delta,
          version: version
        )
      end

      {:ok, deltas} = Redis.list_deltas([])
      assert length(deltas) == 2
    end
  end
end
