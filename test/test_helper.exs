ExUnit.start()

# Define mocks for the backend and time behavior
Mox.defmock(Chord.Backend.Mock, for: Chord.Backend.Behaviour)
Mox.defmock(Chord.Utils.Time.Mock, for: Chord.Utils.Time.Behaviour)

# Shared helper functions
defmodule TestHelpers do
  require ExUnit.Assertions

  # General Utilities
  def allow_sharing_expectation(mock, owner_pid, allowed_via) do
    Mox.allow(mock, owner_pid, allowed_via)
  end

  def mock_time_expectation(opts, times \\ 1) do
    unit = Keyword.get(opts, :unit)
    time = Keyword.get(opts, :time)
    Mox.expect(Chord.Utils.Time.Mock, :current_time, times, fn ^unit -> time end)
  end

  # Context Expectations
  def mock_set_context_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    context = Keyword.get(opts, :context)
    version = Keyword.get(opts, :version)
    inserted_at = Keyword.get(opts, :inserted_at)

    Mox.expect(Chord.Backend.Mock, :set_context, times, fn ^context_id, ^context, ^version ->
      {:ok,
       %{context_id: context_id, context: context, version: version, inserted_at: inserted_at}}
    end)
  end

  def mock_get_context_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    context = Keyword.get(opts, :context)
    version = Keyword.get(opts, :version)
    inserted_at = Keyword.get(opts, :inserted_at)
    error = Keyword.get(opts, :error)

    if is_tuple(error) do
      Mox.expect(Chord.Backend.Mock, :get_context, times, fn ^context_id ->
        error
      end)
    else
      Mox.expect(Chord.Backend.Mock, :get_context, times, fn ^context_id ->
        {:ok,
         %{context_id: context_id, context: context, version: version, inserted_at: inserted_at}}
      end)
    end
  end

  def mock_delete_context_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)

    Mox.expect(Chord.Backend.Mock, :delete_context, times, fn ^context_id -> :ok end)
  end

  # Delta Expectations
  def mock_set_delta_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    delta = Keyword.get(opts, :delta)
    version = Keyword.get(opts, :version)
    inserted_at = Keyword.get(opts, :inserted_at)

    Mox.expect(Chord.Backend.Mock, :set_delta, times, fn ^context_id, ^delta, ^version ->
      {:ok, %{context_id: context_id, delta: delta, version: version, inserted_at: inserted_at}}
    end)
  end

  def mock_get_deltas_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    delta = Keyword.get(opts, :delta)
    version = Keyword.get(opts, :version)
    inserted_at = Keyword.get(opts, :inserted_at)
    error = Keyword.get(opts, :error)

    if is_tuple(error) do
      Mox.expect(Chord.Backend.Mock, :get_deltas, times, fn ^context_id, ^version ->
        error
      end)
    else
      Mox.expect(Chord.Backend.Mock, :get_deltas, times, fn ^context_id, ^version ->
        delta = %{
          context_id: context_id,
          delta: delta,
          version: version + 1,
          inserted_at: inserted_at
        }

        {:ok, List.wrap(delta)}
      end)
    end
  end

  def mock_delete_deltas_by_time(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    older_than_time = Keyword.get(opts, :older_than_time)

    Mox.expect(Chord.Backend.Mock, :delete_deltas_by_time, times, fn ^context_id,
                                                                     ^older_than_time ->
      :ok
    end)
  end

  def mock_delete_deltas_exceeding_threshold(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    threshold = Keyword.get(opts, :threshold)

    Mox.expect(Chord.Backend.Mock, :delete_deltas_exceeding_threshold, times, fn ^context_id,
                                                                                 ^threshold ->
      :ok
    end)
  end

  def mock_delete_deltas_for_context_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)

    Mox.expect(Chord.Backend.Mock, :delete_deltas_for_context, times, fn ^context_id ->
      :ok
    end)
  end

  # Listing Expectations
  def mock_list_contexts_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    inserted_at = Keyword.get(opts, :inserted_at)
    limit = Keyword.get(opts, :limit)

    Mox.expect(Chord.Backend.Mock, :list_contexts, times, fn opts ->
      if not is_nil(limit), do: ExUnit.Assertions.assert(opts[:limit] == limit)

      if not is_nil(context_id) and not is_nil(inserted_at) do
        {:ok, [%{context_id: context_id, inserted_at: inserted_at}]}
      else
        {:ok, []}
      end
    end)
  end

  def mock_list_contexts_with_delta_counts_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    count = Keyword.get(opts, :count)

    Mox.expect(Chord.Backend.Mock, :list_contexts_with_delta_counts, times, fn _opts ->
      if not is_nil(context_id) and not is_nil(count) do
        {:ok, [%{context_id: context_id, count: count}]}
      else
        {:ok, []}
      end
    end)
  end

  def mock_list_deltas_expectation(opts, times \\ 1) do
    context_id = Keyword.get(opts, :context_id)
    inserted_at = Keyword.get(opts, :inserted_at)
    limit = Keyword.get(opts, :limit)

    Mox.expect(Chord.Backend.Mock, :list_deltas, times, fn opts ->
      if not is_nil(limit), do: ExUnit.Assertions.assert(opts[:limit] == limit)

      if not is_nil(context_id) and not is_nil(inserted_at) do
        {:ok, [%{context_id: context_id, inserted_at: inserted_at}]}
      else
        {:ok, []}
      end
    end)
  end
end
