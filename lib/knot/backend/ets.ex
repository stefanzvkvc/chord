defmodule Knot.Backend.ETS do
  @moduledoc """
  ETS-based backend with versioning support, global state per context, and device-specific deltas.
  """
  @behaviour Knot.Backend.Behaviour
  @state_table :knot_state_table
  @history_table :knot_state_history_table

  # State operations
  @impl true
  def set_state(context_id, state, version) do
    ensure_table_exists()
    timestamp = :os.system_time(:second)
    :ets.insert(@state_table, {context_id, state, version, timestamp})
    :ok
  end

  @impl true
  def get_state(context_id) do
    ensure_table_exists()

    case :ets.lookup(@state_table, context_id) do
      [{^context_id, state, version, _timestamp}] -> {state, version}
      [] -> {%{}, 0}
    end
  end

  @impl true
  def delete_state(context_id) do
    ensure_table_exists()

    # Remove all deltas for this context
    :ets.select_delete(@history_table, [
      {{{context_id, :_, :_}, :_, :_}, [], [true]}
    ])

    # Remove state for this context
    :ets.delete(@state_table, context_id)

    :ok
  end

  # Delta operations
  @impl true
  def set_delta(context_id, device_id, delta, version) do
    ensure_table_exists()
    timestamp = :os.system_time(:second)
    :ets.insert(@history_table, {{context_id, device_id, version}, delta, timestamp})
    :ok
  end

  @impl true
  def get_delta(context_id, device_id, client_version) do
    ensure_table_exists()
    # Match all entries for this context_id and device_id
    pattern = {{context_id, device_id, :_}, :_, :_}
    all = :ets.match_object(@history_table, pattern)

    Enum.filter(all, fn {{_context_id, _device_id, version}, _delta, _timestamp} ->
      version > client_version
    end)
    |> Enum.map(fn {_, delta, _timestamp} -> delta end)
  end

  @impl true
  def delete_deltas_by_device(context_id, device_id) do
    ensure_table_exists()

    # Remove all deltas for this context and device
    :ets.select_delete(@history_table, [
      {{{context_id, device_id, :_}, :_, :_}, [], [true]}
    ])

    :ok
  end

  @impl true
  def delete_deltas_by_version(context_id, device_id, version_threshold) do
    ensure_table_exists()
    pattern = {{context_id, device_id, :_}, :_, :_}
    all = :ets.match_object(@history_table, pattern)

    # Optimize deleting deltas by filtering relevant delta for deletion first
    Enum.each(all, fn {{context_id, device_id, version}, _delta, _timestamp} ->
      if version < version_threshold do
        :ets.delete(@history_table, {context_id, device_id, version})
      end
    end)

    :ok
  end

  @impl true
  def delete_deltas_by_time(context_id, device_id, older_than_timestamp) do
    ensure_table_exists()
    pattern = {{context_id, device_id, :_}, :_, :_}
    all = :ets.match_object(@history_table, pattern)

    all
    |> Enum.filter(fn {_, _, timestamp} -> timestamp < older_than_timestamp end)
    |> Enum.each(fn entry ->
      :ets.delete_object(@history_table, entry)
    end)

    :ok
  end

  # Listing operations
  @impl true
  def list_states(opts \\ []) do
    limit = Keyword.get(opts, :limit, :infinity)
    offset = Keyword.get(opts, :offset, 0)

    :ets.foldl(
      fn {context_id, state, version, timestamp}, acc ->
        if filter_match?(%{context_id: context_id, version: version, timestamp: timestamp}, opts) do
          [%{context_id: context_id, state: state, version: version, timestamp: timestamp} | acc]
        else
          acc
        end
      end,
      [],
      @state_table
    )
    |> Enum.reverse()
    |> Enum.slice(offset, limit)
  end

  @impl true
  def list_devices(opts \\ []) do
    limit = Keyword.get(opts, :limit, :infinity)
    offset = Keyword.get(opts, :offset, 0)

    :ets.foldl(
      fn {{context_id, device_id, version}, delta, timestamp}, acc ->
        if filter_match?(
             %{
               context_id: context_id,
               device_id: device_id,
               version: version,
               timestamp: timestamp
             },
             opts
           ) do
          [
            %{
              context_id: context_id,
              device_id: device_id,
              delta: delta,
              version: version,
              timestamp: timestamp
            }
            | acc
          ]
        else
          acc
        end
      end,
      [],
      @history_table
    )
    |> Enum.reverse()
    |> Enum.slice(offset, limit)
  end

  # Context activity
  @impl true
  def get_last_activity_timestamp(context_id) do
    ensure_table_exists()
    # The last activity is stored in state_table as timestamps for global state updates
    case :ets.lookup(@state_table, context_id) do
      [{^context_id, _state, _version, timestamp}] -> timestamp
      [] -> nil
    end
  end

  defp filter_match?(record, opts) do
    Enum.all?(opts, fn
      {:context_id, id} -> record.context_id == id
      {:device_id, id} -> record.device_id == id
      {:version, version} -> record.version == version
      {:timestamp, timestamp} -> record.timestamp >= timestamp
      _ -> true
    end)
  end

  defp ensure_table_exists do
    if :ets.info(@state_table) == :undefined do
      :ets.new(@state_table, [:named_table, :set, :public])
    end

    if :ets.info(@history_table) == :undefined do
      :ets.new(@history_table, [:named_table, :set, :public])
    end
  end
end
