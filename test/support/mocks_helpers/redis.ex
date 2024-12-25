defmodule Chord.Support.MocksHelpers.Redis do
  # Define expectations for Redix commands.
  def mock_hset(opts) do
    context_id = opts[:context_id]
    key = "chord:context:#{context_id}"

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
      key = "chord:context:#{context_id}"

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
    key = "chord:context:#{opts[:context_id]}"

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["DEL", ^key] ->
      {:ok, 1}
    end)
  end

  def mock_zadd(opts) do
    context_id = opts[:context_id]
    version = opts[:version]
    delta = opts[:delta]
    inserted_at = opts[:inserted_at]

    delta = prepare_payload(:delta, delta, version, inserted_at)
    delta = serialize_payload(:delta, delta)
    version = Integer.to_string(version)
    key = "chord:delta:#{context_id}"

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
      delta = prepare_payload(:delta, delta, version, inserted_at)
      delta = serialize_payload(:delta, delta)

      key = "chord:delta:#{context_id}"

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
    key = "chord:delta:#{context_id}"

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["DEL", ^key] ->
      {:ok, 1}
    end)
  end

  def mock_zremrangebyscore(opts) do
    context_id = opts[:context_id]
    older_than_time = "(#{opts[:older_than_time]}"
    key = "chord:delta:#{context_id}"

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
    key = "chord:delta:#{context_id}"

    Mox.expect(Chord.Support.Mocks.Redis, :command, fn ["ZCARD", ^key] ->
      {:ok, count}
    end)
  end

  def mock_zremrangebyrank(opts) do
    context_id = opts[:context_id]
    rank_limit = opts[:rank_limit] |> Integer.to_string()
    key = "chord:delta:#{context_id}"

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

  defp prepare_payload(:context, data, version, inserted_at) do
    %{
      context: data,
      version: version,
      inserted_at: inserted_at
    }
  end

  defp prepare_payload(:delta, data, version, inserted_at) do
    %{
      delta: data,
      version: version,
      inserted_at: inserted_at
    }
  end

  defp serialize_payload(:context, payload) do
    payload
    |> Map.update!(:context, &term_to_binary/1)
    |> to_redis_format(:context)
  end

  defp serialize_payload(:delta, payload) do
    payload
    |> Map.update!(:delta, &(&1 |> term_to_binary() |> Base.encode64()))
    |> to_redis_format(:delta)
  end

  defp to_redis_format(payload, :context) do
    Enum.flat_map(payload, fn {k, v} -> [Atom.to_string(k), v] end)
  end

  defp to_redis_format(payload, :delta) do
    Jason.encode!(payload)
  end

  defp term_to_binary(term), do: :erlang.term_to_binary(term)
end
