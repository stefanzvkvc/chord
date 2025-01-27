defmodule Chord.Support.MocksHelpers.Backend do
  @moduledoc false
  require ExUnit.Assertions
  alias Chord.Support.Mocks.Backend

  # Context Expectations
  def mock_set_context(opts, times \\ 1) do
    context_id = opts[:context_id]
    context = opts[:context]
    version = opts[:version]
    inserted_at = opts[:inserted_at]

    Mox.expect(Backend, :set_context, times, fn ^context_id, ^context, ^version ->
      {:ok,
       %{context_id: context_id, context: context, version: version, inserted_at: inserted_at}}
    end)
  end

  def mock_get_context(opts, times \\ 1) do
    context_id = opts[:context_id]
    error = opts[:error]

    if error do
      Mox.expect(Backend, :get_context, times, fn ^context_id -> error end)
    else
      context = opts[:context]
      version = opts[:version]
      inserted_at = opts[:inserted_at]

      Mox.expect(Backend, :get_context, times, fn ^context_id ->
        {:ok,
         %{context_id: context_id, context: context, version: version, inserted_at: inserted_at}}
      end)
    end
  end

  def mock_delete_context(opts, times \\ 1) do
    context_id = opts[:context_id]

    Mox.expect(Backend, :delete_context, times, fn ^context_id -> :ok end)
  end

  # Delta Expectations
  def mock_set_delta(opts, times \\ 1) do
    context_id = opts[:context_id]
    delta = opts[:delta]
    version = opts[:version]
    inserted_at = opts[:inserted_at]

    Mox.expect(Backend, :set_delta, times, fn ^context_id, ^delta, ^version ->
      {:ok, %{context_id: context_id, delta: delta, version: version, inserted_at: inserted_at}}
    end)
  end

  def mock_get_deltas(opts, times \\ 1) do
    context_id = opts[:context_id]
    version = opts[:version]
    error = opts[:error]

    if error do
      Mox.expect(Backend, :get_deltas, times, fn ^context_id, ^version -> error end)
    else
      delta = opts[:delta]
      inserted_at = opts[:inserted_at]

      Mox.expect(Backend, :get_deltas, times, fn ^context_id, ^version ->
        {:ok,
         [%{context_id: context_id, delta: delta, version: version + 1, inserted_at: inserted_at}]}
      end)
    end
  end

  def mock_delete_deltas_by_time(opts, times \\ 1) do
    context_id = opts[:context_id]
    older_than_time = opts[:older_than_time]

    Mox.expect(Backend, :delete_deltas_by_time, times, fn ^context_id, ^older_than_time -> :ok end)
  end

  def mock_delete_deltas_exceeding_threshold(opts, times \\ 1) do
    context_id = opts[:context_id]
    threshold = opts[:threshold]

    Mox.expect(Backend, :delete_deltas_exceeding_threshold, times, fn ^context_id, ^threshold ->
      :ok
    end)
  end

  def mock_delete_deltas_for_context(opts, times \\ 1) do
    context_id = opts[:context_id]

    Mox.expect(Backend, :delete_deltas_for_context, times, fn ^context_id -> :ok end)
  end

  # Listing Expectations
  def mock_list_contexts(opts, times \\ 1) do
    limit = opts[:limit]
    context_id = opts[:context_id]
    inserted_at = opts[:inserted_at]

    Mox.expect(Backend, :list_contexts, times, fn actual_opts ->
      if limit do
        ExUnit.Assertions.assert(actual_opts[:limit] == limit)
      end

      if context_id && inserted_at do
        {:ok, [%{context_id: context_id, inserted_at: inserted_at}]}
      else
        {:ok, []}
      end
    end)
  end

  def mock_list_contexts_with_delta_counts(opts, times \\ 1) do
    context_id = opts[:context_id]
    count = opts[:count]

    Mox.expect(Backend, :list_contexts_with_delta_counts, times, fn _ ->
      if context_id && count do
        {:ok, [%{context_id: context_id, count: count}]}
      else
        {:ok, []}
      end
    end)
  end

  def mock_list_deltas(opts, times \\ 1) do
    limit = opts[:limit]
    context_id = opts[:context_id]
    inserted_at = opts[:inserted_at]

    Mox.expect(Backend, :list_deltas, times, fn actual_opts ->
      if limit do
        ExUnit.Assertions.assert(actual_opts[:limit] == limit)
      end

      if context_id && inserted_at do
        {:ok, [%{context_id: context_id, inserted_at: inserted_at}]}
      else
        {:ok, []}
      end
    end)
  end
end
