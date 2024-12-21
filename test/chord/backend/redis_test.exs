defmodule Chord.Backend.RedisTest do
  use ExUnit.Case
  alias Chord.Backend.Redis

  setup do
    # Mock time and Redis client
    Application.put_env(:chord, :time, Chord.Utils.Time.Mock)
    Application.put_env(:chord, :redis_client, Chord.Backend.Mock)

    {:ok, current_time: 1_673_253_120}
  end

  describe "Context Operations" do
    test "set_context and get_context", %{current_time: current_time} do
      Mock.expect(:command, fn ["HSET", _key | _values] -> {:ok, 1} end)

      Mock.expect(:command, fn ["HGETALL", _key] ->
        {:ok, ["context", :erlang.term_to_binary(%{}), "version", "1"]}
      end)

      assert Redis.set_context("context_id", %{}, 1) == {:ok, {%{}, 1}}
      assert Redis.get_context("context_id") == {:ok, {%{}, 1}}
    end

    test "list_contexts_with_delta_counts" do
      Mock.expect(:command, fn ["KEYS", "chord:delta:*"] ->
        {:ok, ["chord:delta:ctx1", "chord:delta:ctx2"]}
      end)

      Mock.expect(:command, fn ["ZCARD", "chord:delta:ctx1"] -> {:ok, 5} end)
      Mock.expect(:command, fn ["ZCARD", "chord:delta:ctx2"] -> {:ok, 3} end)

      assert Redis.list_contexts_with_delta_counts() ==
               {:ok, [%{context_id: "ctx1", count: 5}, %{context_id: "ctx2", count: 3}]}
    end
  end
end
