defmodule Chord.Backend.Redis do
  @moduledoc """
  Redis-based backend for Chord, providing context-level state and delta management
  with versioning support.

  ## Configuration

  To use Redis as a backend, follow these steps:

  1. Start a Redis connection process using `Redix` with your desired configuration:

    ```elixir
    {:ok, _} = Redix.start_link("redis://localhost:6379", name: :my_redis)
    ```

  2. Set the Redis client in the application environment:

    ```elixir
    Application.put_env(:chord, :redis_client, :my_redis)
    ```
  """

  @behaviour Chord.Backend.Behaviour
  @default_time_provider Chord.Utils.Time
  @context_prefix "chord:context"
  @delta_prefix "chord:delta"

  # Context Operations
  @impl true
  def set_context(context_id, context, version) do
    key = redis_key(@context_prefix, context_id)
    inserted_at = time_provider().current_time(:second)
    payload = prepare_payload(:context, context, version, inserted_at)

    execute_redis(["HSET", key | serialize_payload(:context, payload)], fn _ ->
      {:ok, Map.put(payload, :context_id, context_id)}
    end)
  end

  @impl true
  def get_context(context_id) do
    key = redis_key(@context_prefix, context_id)

    execute_redis(["HGETALL", key], fn
      [] ->
        {:error, :not_found}

      result ->
        map = deserialize_hash(result)
        {:ok, deserialize_payload(:context, map, context_id)}
    end)
  end

  @impl true
  def delete_context(context_id) do
    key = redis_key(@context_prefix, context_id)
    execute_redis(["DEL", key], fn _ -> :ok end)
  end

  # Delta Operations
  @impl true
  def set_delta(context_id, delta, version) do
    key = redis_key(@delta_prefix, context_id)
    inserted_at = time_provider().current_time(:second)
    payload = prepare_payload(:delta, delta, version, inserted_at)

    execute_redis(["ZADD", key, "#{version}", serialize_payload(:delta, payload)], fn _ ->
      {:ok, Map.put(payload, :context_id, context_id)}
    end)
  end

  @impl true
  def get_deltas(context_id, client_version) do
    key = redis_key(@delta_prefix, context_id)

    execute_redis(["ZRANGEBYSCORE", key, "#{client_version + 1}", "+inf"], fn
      [] ->
        {:error, :not_found}

      result ->
        deltas = Enum.map(result, &deserialize_payload(:delta, &1, context_id))

        {:ok, deltas}
    end)
  end

  @impl true
  def delete_deltas_for_context(context_id) do
    key = redis_key(@delta_prefix, context_id)
    execute_redis(["DEL", key], fn _ -> :ok end)
  end

  @impl true
  def delete_deltas_by_time(context_id, older_than_time) do
    key = redis_key(@delta_prefix, context_id)
    execute_redis(["ZREMRANGEBYSCORE", key, "-inf", "(#{older_than_time}"], fn _ -> :ok end)
  end

  @impl true
  def delete_deltas_exceeding_threshold(context_id, threshold) do
    key = redis_key(@delta_prefix, context_id)

    execute_redis(["ZCARD", key], fn
      count when count > threshold ->
        execute_redis(["ZREMRANGEBYRANK", key, "0", "#{count - threshold - 1}"], fn _ -> :ok end)

      _ ->
        :ok
    end)
  end

  @impl true
  def list_contexts(opts \\ []) do
    list_keys_with_pattern(@context_prefix, opts, &get_context/1)
  end

  @impl true
  def list_deltas(opts \\ []) do
    list_keys_with_pattern(@delta_prefix, opts, fn id -> get_deltas(id, 0) end)
  end

  @impl true
  def list_contexts_with_delta_counts(_opts) do
    pattern = redis_key(@delta_prefix, "*")

    execute_redis(["KEYS", pattern], fn
      [] ->
        {:ok, []}

      keys ->
        counts = Enum.map(keys, &fetch_delta_count/1)
        {:ok, counts}
    end)
  end

  # Helpers
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

  defp deserialize_payload(:context, map, context_id) do
    %{
      context_id: context_id,
      context: binary_to_term(map["context"]),
      version: String.to_integer(map["version"]),
      inserted_at: String.to_integer(map["inserted_at"])
    }
  end

  defp deserialize_payload(:delta, map, context_id) do
    map = Jason.decode!(map)

    %{
      context_id: context_id,
      delta: map["delta"] |> Base.decode64!() |> binary_to_term(),
      version: map["version"],
      inserted_at: map["inserted_at"]
    }
  end

  defp deserialize_hash(payload) do
    payload
    |> Enum.chunk_every(2)
    |> Enum.map(fn [key, value] -> {key, value} end)
    |> Map.new()
  end

  defp to_redis_format(payload, :context) do
    Enum.flat_map(payload, fn {k, v} -> [Atom.to_string(k), v] end)
  end

  defp to_redis_format(payload, :delta) do
    Jason.encode!(payload)
  end

  defp fetch_delta_count(key) do
    [_, _, context_id] = String.split(key, ":")
    {:ok, count} = execute_redis(["ZCARD", key], fn res -> {:ok, res} end)
    %{context_id: context_id, count: count}
  end

  defp list_keys_with_pattern(prefix, opts, fetch_fun) do
    pattern = redis_key(prefix, "*")

    execute_redis(["KEYS", pattern], fn
      [] ->
        {:ok, []}

      keys ->
        results = fetch_results(keys, prefix, fetch_fun)
        {:ok, apply_list_filters(results, opts)}
    end)
  end

  defp fetch_results(keys, prefix, fetch_fun) do
    Enum.flat_map(keys, fn key ->
      param = String.replace_prefix(key, prefix <> ":", "")

      case fetch_fun.(param) do
        {:ok, result} -> List.wrap(result)
        _ -> []
      end
    end)
  end

  defp apply_list_filters(list, opts) do
    limit = Keyword.get(opts, :limit, :infinity)
    offset = Keyword.get(opts, :offset, 0)
    order = Keyword.get(opts, :order, :asc)

    list
    |> maybe_reverse(order)
    |> apply_offset_and_limit(offset, limit)
  end

  defp maybe_reverse(list, :asc), do: list
  defp maybe_reverse(list, :desc), do: Enum.reverse(list)

  defp apply_offset_and_limit(list, offset, :infinity) do
    Enum.drop(list, offset)
  end

  defp apply_offset_and_limit(list, offset, limit) do
    Enum.slice(list, offset, limit)
  end

  defp redis_key(prefix, context_id), do: "#{prefix}:#{context_id}"

  defp execute_redis(command, callback) do
    command
    |> Chord.Utils.Redis.Client.command()
    |> case do
      {:ok, result} ->
        callback.(result)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp binary_to_term(binary), do: :erlang.binary_to_term(binary)
  defp term_to_binary(term), do: :erlang.term_to_binary(term)
  defp time_provider, do: Application.get_env(:chord, :time_provider, @default_time_provider)
end
