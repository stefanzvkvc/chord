defmodule Chord.Backend.Redis do
  @moduledoc """
  Redis-based backend for Chord, providing context-level state and delta management
  with versioning support.

  ## Configuration

  Configure the Redis connection in your application:

      config :chord, :redis,
        url: "redis://localhost:6379",
        pool_size: 5
  """

  @behaviour Chord.Backend.Behaviour

  alias Redix, as: RedisClient

  @context_prefix "chord:context"
  @delta_prefix "chord:delta"

  # Context Operations
  @impl true
  def set_context(context_id, context, version) do
    key = "#{@context_prefix}:#{context_id}"
    inserted_at = current_time()
    context = term_to_binary(context)

    payload = %{
      "context" => context,
      "version" => version,
      "inserted_at" => inserted_at
    }

    execute_redis(["HSET", key | serialize_hash(payload)], fn _ ->
      {:ok,
       %{context_id: context_id, context: context, version: version, inserted_at: inserted_at}}
    end)
  end

  @impl true
  def get_context(context_id) do
    key = "#{@context_prefix}:#{context_id}"

    execute_redis(["HGETALL", key], fn
      [] ->
        {:error, :not_found}

      result ->
        map = deserialize_hash(result)

        {:ok,
         %{
           context_id: context_id,
           context: binary_to_term(map["context"]),
           version: String.to_integer(map["version"]),
           inserted_at: String.to_integer(map["inserted_at"])
         }}
    end)
  end

  @impl true
  def delete_context(context_id) do
    key = "#{@context_prefix}:#{context_id}"
    execute_redis(["DEL", key], fn _ -> :ok end)
  end

  # Delta Operations
  @impl true
  def set_delta(context_id, delta, version) do
    key = "#{@delta_prefix}:#{context_id}"
    inserted_at = Integer.to_string(current_time())

    delta =
      delta
      |> term_to_binary()
      |> Base.encode64()

    payload = %{
      "version" => version,
      "delta" => delta,
      "inserted_at" => inserted_at
    }

    execute_redis(["ZADD", key, "#{version}", serialize(payload)], fn _ ->
      {:ok,
       %{
         context_id: context_id,
         delta: delta,
         version: version,
         inserted_at: String.to_integer(inserted_at)
       }}
    end)
  end

  @impl true
  def get_deltas(context_id, client_version) do
    key = "#{@delta_prefix}:#{context_id}"

    execute_redis(["ZRANGEBYSCORE", key, "#{client_version + 1}", "+inf"], fn
      [] ->
        {:error, :not_found}

      result ->
        deltas =
          Enum.map(result, fn item ->
            map = deserialize(item)
            binary_delta = Base.decode64!(map["delta"])
            delta = binary_to_term(binary_delta)

            %{
              context_id: context_id,
              delta: delta,
              version: map["version"],
              inserted_at: map["inserted_at"]
            }
          end)

        {:ok, deltas}
    end)
  end

  @impl true
  def delete_deltas_for_context(context_id) do
    key = "#{@delta_prefix}:#{context_id}"
    execute_redis(["DEL", key], fn _ -> :ok end)
  end

  @impl true
  def delete_deltas_by_time(context_id, older_than_time) do
    key = "#{@delta_prefix}:#{context_id}"
    execute_redis(["ZREMRANGEBYSCORE", key, "-inf", "(#{older_than_time}"], fn _ -> :ok end)
  end

  @impl true
  def delete_deltas_exceeding_threshold(context_id, threshold) do
    key = "#{@delta_prefix}:#{context_id}"

    execute_redis(["ZCARD", key], fn
      count when count > threshold ->
        execute_redis(["ZREMRANGEBYRANK", key, "0", "#{count - threshold - 1}"], fn _ -> :ok end)

      _ ->
        :ok
    end)
  end

  @impl true
  def list_contexts(opts \\ []) do
    list_keys_with_pattern(@context_prefix, opts, :contexts)
  end

  @impl true
  def list_deltas(opts \\ []) do
    list_keys_with_pattern(@delta_prefix, opts, :deltas)
  end

  @impl true
  def list_contexts_with_delta_counts(_opts) do
    pattern = "#{@delta_prefix}:*"

    execute_redis(["KEYS", pattern], fn
      [] ->
        {:ok, []}

      keys ->
        counts =
          Enum.map(keys, fn key ->
            [_, context_id] = String.split(key, ":")
            {:ok, count} = execute_redis(["ZCARD", key], fn res -> {:ok, res} end)
            %{context_id: context_id, count: count}
          end)

        {:ok, counts}
    end)
  end

  # Helpers
  defp list_keys_with_pattern(prefix, opts, type) do
    pattern = "#{prefix}:*"

    execute_redis(["KEYS", pattern], fn
      [] ->
        {:ok, []}

      keys ->
        {:ok, results} =
          Enum.flat_map(keys, fn key ->
            id = String.replace(key, "#{prefix}:", "")

            case type do
              :contexts -> get_context(id)
              :deltas -> get_deltas(id, 0)
            end
          end)

        {:ok, results |> apply_list_filters(opts)}
    end)
  end

  defp apply_list_filters(list, opts) do
    limit = Keyword.get(opts, :limit, :infinity)
    offset = Keyword.get(opts, :offset, 0)
    order = Keyword.get(opts, :order, :asc)

    list
    |> maybe_reverse(order)
    |> Enum.slice(offset, limit)
  end

  defp maybe_reverse(list, :asc), do: list
  defp maybe_reverse(list, :desc), do: Enum.reverse(list)

  defp execute_redis(command, callback) do
    redis_client()
    |> RedisClient.command(command)
    |> case do
      {:ok, result} -> callback.(result)
      {:error, reason} -> {:error, reason}
    end
  end

  defp redis_client(), do: Application.fetch_env!(:chord, :redis_client)
  defp current_time, do: Application.fetch_env!(:chord, :time_provider).current_time(:second)

  defp serialize(payload), do: Jason.encode!(payload)
  defp deserialize(payload), do: Jason.decode!(payload)
  defp serialize_hash(payload), do: Enum.flat_map(payload, fn {k, v} -> [k, v] end)

  defp deserialize_hash(payload) do
    payload
    |> Enum.chunk_every(2)
    |> Enum.map(fn [key, value] -> {key, value} end)
    |> Map.new()
  end

  defp binary_to_term(binary), do: :erlang.binary_to_term(binary)
  defp term_to_binary(term), do: :erlang.term_to_binary(term)
end
