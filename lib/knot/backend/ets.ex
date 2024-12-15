defmodule Knot.Backend.ETS do
  @moduledoc """
  ETS-based backend for Knot, providing context-level state and delta management
  with versioning support. Both tables use `:ordered_set` to leverage efficient
  key ordering for listing and cleanup operations.
  """
  @behaviour Knot.Backend.Behaviour
  @context_table :knot_context_table
  @context_history_table :knot_context_history_table

  # Context operations
  @impl true
  def set_context(context_id, context, version) do
    ensure_table_exists()
    inserted_at = time().current_time(:second)
    :ets.insert(@context_table, {{context_id, inserted_at}, context, version})
    {:ok, {context, version}}
  end

  @impl true
  def get_context(context_id) do
    ensure_table_exists()

    case :ets.match_object(@context_table, {{context_id, :"$1"}, :"$2", :"$3"}) do
      [{{^context_id, _inserted_at}, context, version}] -> {:ok, {context, version}}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def delete_context(context_id) do
    ensure_table_exists()

    match_spec = [
      {{{context_id, :_}, :_, :_}, [], [true]}
    ]

    delete_with_match_spec(@context_table, match_spec)

    :ok
  end

  # Delta operations
  @impl true
  def set_delta(context_id, delta, version) do
    ensure_table_exists()
    inserted_at = time().current_time(:second)
    :ets.insert(@context_history_table, {{context_id, version}, delta, inserted_at})
    {:ok, {delta, version}}
  end

  @impl true
  def get_deltas(context_id, client_version) do
    ensure_table_exists()

    match_spec = [
      {{{context_id, :"$1"}, :"$2", :_}, [{:>, :"$1", client_version}], [:"$2"]}
    ]

    :ets.select(@context_history_table, match_spec)
    |> case do
      [] -> {:error, :not_found}
      deltas -> {:ok, deltas}
    end
  end

  @impl true
  def delete_deltas_for_context(context_id) do
    ensure_table_exists()

    match_spec = [
      {{{context_id, :_}, :_, :_}, [], [true]}
    ]

    delete_with_match_spec(@context_history_table, match_spec)
    :ok
  end

  @impl true
  def delete_deltas_by_time(context_id, older_than_time) do
    ensure_table_exists()

    match_spec = [
      {{{context_id, :_}, :_, :"$1"}, [{:<, :"$1", older_than_time}], [true]}
    ]

    delete_with_match_spec(@context_history_table, match_spec)

    :ok
  end

  @impl true
  def delete_deltas_exceeding_threshold(context_id, threshold) do
    ensure_table_exists()

    match_spec = [
      {{{context_id, :"$1"}, :_, :_}, [], [:"$1"]}
    ]

    :ets.select(@context_history_table, match_spec)
    |> Enum.sort()
    |> Enum.drop(threshold)
    |> Enum.each(fn version ->
      delete_with_match_spec(@context_history_table, [
        {{{context_id, version}, :_, :_}, [], [true]}
      ])
    end)

    :ok
  end

  # Listing operations
  @impl true
  def list_contexts(opts \\ []) do
    match_spec = build_context_match_spec(opts)

    result = :ets.select(@context_table, match_spec)
    slice_and_return(result, opts, :contexts)
  end

  @impl true
  def list_contexts_with_delta_counts(_opts) do
    match_spec = [{{{:"$1", :_}, :_, :_}, [], [:"$1"]}]
    grouped = :ets.select(@context_history_table, match_spec)
    counts = Enum.frequencies(grouped)

    contexts_with_counts =
      Enum.map(counts, fn {context_id, count} ->
        %{context_id: context_id, count: count}
      end)

    {:ok, contexts_with_counts}
  end

  @impl true
  def list_deltas(opts \\ []) do
    match_spec = build_deltas_match_spec(opts)

    result = :ets.select(@context_history_table, match_spec)

    sorted =
      Enum.sort_by(result, fn {context_id, version, _delta, _inserted_at} ->
        {context_id, version}
      end)

    slice_and_return(sorted, opts, :deltas)
  end

  defp build_context_match_spec(opts) do
    conditions =
      opts
      |> Enum.map(fn
        {:context_id, id} -> {:==, :"$1", id}
        {:version, version} -> {:==, :"$4", version}
        {:inserted_at, inserted_at} -> {:>=, :"$2", inserted_at}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    [
      {
        # Match composite key and fields
        {{:"$1", :"$2"}, :"$3", :"$4"},
        # Apply optional filters
        conditions,
        [{{:"$1", :"$2", :"$3", :"$4"}}]
      }
    ]
  end

  defp build_deltas_match_spec(opts) do
    conditions =
      opts
      |> Enum.map(fn
        {:context_id, id} -> {:==, :"$1", id}
        {:version, version} -> {:==, :"$2", version}
        {:inserted_at, inserted_at} -> {:>=, :"$4", inserted_at}
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    [
      {
        # Match composite key and fields
        {{:"$1", :"$2"}, :"$3", :"$4"},
        # Apply optional filters
        conditions,
        [{{:"$1", :"$2", :"$3", :"$4"}}]
      }
    ]
  end

  # Common utility functions
  defp delete_with_match_spec(table, match_spec) do
    :ets.select_delete(table, match_spec)
  end

  defp slice_and_return(result, opts, type) do
    limit = Keyword.get(opts, :limit, :infinity)
    offset = Keyword.get(opts, :offset, 0)
    order = Keyword.get(opts, :order, :asc)

    result
    |> maybe_reverse(order)
    |> maybe_slice(offset, limit)
    |> normalize_data(type)
    |> case do
      [] -> {:ok, []}
      contexts -> {:ok, contexts}
    end
  end

  defp maybe_reverse(list, :asc), do: list
  defp maybe_reverse(list, :desc), do: Enum.reverse(list)
  defp maybe_slice(list, offset, :infinity), do: Enum.drop(list, offset)
  defp maybe_slice(list, offset, limit), do: Enum.slice(list, offset, limit)

  defp normalize_data(list, :contexts) do
    Enum.map(list, fn {context_id, inserted_at, context, version} ->
      %{
        context_id: context_id,
        context: context,
        version: version,
        inserted_at: inserted_at
      }
    end)
  end

  defp normalize_data(list, :deltas) do
    Enum.map(list, fn {context_id, version, delta, inserted_at} ->
      %{
        context_id: context_id,
        delta: delta,
        version: version,
        inserted_at: inserted_at
      }
    end)
  end

  defp ensure_table_exists do
    tables = [
      {@context_table, [:ordered_set, :named_table, :public]},
      {@context_history_table, [:ordered_set, :named_table, :public]}
    ]

    Enum.each(tables, fn {table, options} ->
      if :ets.info(table) == :undefined do
        :ets.new(table, options)
      end
    end)
  end

  defp time() do
    Application.get_env(:knot, :time, Knot.Utils.Time)
  end
end
