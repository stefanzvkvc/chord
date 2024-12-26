defmodule Chord.Support.MocksHelpers.Redis do
  @context_prefix "chord:context"
  @delta_prefix "chord:delta"
  # Define expectations for Redix commands.
  def mock_hset(opts) do
    context_id = opts[:context_id]
    key = redis_key(@context_prefix, context_id)

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["HSET", ^key | values] ->
      result = values |> Enum.chunk_every(2) |> Enum.count()
      {:ok, result}
    end)
  end

  def mock_hgetall(opts) do
    if opts == [] do
      Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["HGETALL", _] ->
        {:ok, []}
      end)
    else
      context_id = opts[:context_id]
      version = opts[:version] |> Integer.to_string()
      context = opts[:context] |> :erlang.term_to_binary()
      inserted_at = opts[:inserted_at] |> Integer.to_string()
      key = redis_key(@context_prefix, context_id)

      Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["HGETALL", ^key] ->
        {:ok,
         [
           "version",
           version,
           "context",
           context,
           "inserted_at",
           inserted_at
         ]}
      end)
    end
  end

  def mock_hdel(opts) do
    context_id = opts[:context_id]
    key = redis_key(@context_prefix, context_id)

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["DEL", ^key] ->
      {:ok, 1}
    end)
  end

  def mock_zadd(opts) do
    context_id = opts[:context_id]
    version = opts[:version]
    delta = opts[:delta]
    inserted_at = opts[:inserted_at]

    delta = %{
      delta: delta |> :erlang.term_to_binary() |> Base.encode64(),
      version: version,
      inserted_at: inserted_at
    }

    delta = Jason.encode!(delta)
    version = Integer.to_string(version)
    key = redis_key(@delta_prefix, context_id)

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn [
                                                         "ZADD",
                                                         ^key,
                                                         ^version,
                                                         ^delta
                                                       ] ->
      {:ok, 1}
    end)
  end

  def mock_zrangebyscore(opts) do
    if opts == [] do
      Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["ZRANGEBYSCORE", _, _, _] ->
        {:ok, []}
      end)
    else
      context_id = opts[:context_id]
      client_version = opts[:client_version]
      version = opts[:version]
      inserted_at = opts[:inserted_at]
      delta = opts[:delta]
      min_version = Integer.to_string(client_version + 1)
      max_version = "+inf"

      delta = %{
        delta: delta |> :erlang.term_to_binary() |> Base.encode64(),
        version: version,
        inserted_at: inserted_at
      }

      delta = Jason.encode!(delta)

      key = redis_key(@delta_prefix, context_id)

      Mox.expect(Chord.Support.Mocks.Redis, :command, fn [
                                                           "ZRANGEBYSCORE",
                                                           ^key,
                                                           ^min_version,
                                                           ^max_version
                                                         ] ->
        {:ok, List.wrap(delta)}
      end)
    end
  end

  def mock_del(opts) do
    context_id = opts[:context_id]
    key = redis_key(@delta_prefix, context_id)

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["DEL", ^key] ->
      {:ok, 1}
    end)
  end

  def mock_zremrangebyscore(opts) do
    context_id = opts[:context_id]
    older_than_time = "(#{opts[:older_than_time]}"
    key = redis_key(@delta_prefix, context_id)

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn [
                                                         "ZREMRANGEBYSCORE",
                                                         ^key,
                                                         "-inf",
                                                         ^older_than_time
                                                       ] ->
      {:ok, 1}
    end)
  end

  def mock_zcard(opts) do
    context_id = opts[:context_id]
    count = opts[:count]
    key = redis_key(@delta_prefix, context_id)

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["ZCARD", ^key] ->
      {:ok, count}
    end)
  end

  def mock_zremrangebyrank(opts) do
    context_id = opts[:context_id]
    rank_limit = opts[:rank_limit] |> Integer.to_string()
    key = redis_key(@delta_prefix, context_id)

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn [
                                                         "ZREMRANGEBYRANK",
                                                         ^key,
                                                         "0",
                                                         ^rank_limit
                                                       ] ->
      {:ok, 5}
    end)
  end

  def mock_keys(opts) do
    pattern = opts[:pattern]
    keys = opts[:keys]

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["KEYS", ^pattern] ->
      {:ok, keys}
    end)
  end

  defp redis_key(prefix, context_id), do: "#{prefix}:#{context_id}"
end
