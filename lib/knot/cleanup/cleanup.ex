defmodule Knot.Cleanup do
  @moduledoc """
  This module provides functionality to clean up data that is no longer needed,
  such as old contexts or deltas, ensuring efficient use of storage and memory.

  ## Key Features
  - **Time-Based Cleanup**: Periodically remove stale contexts or deltas based on configurable time-to-live (TTL) values.
  - **Threshold-Based Cleanup**: Retain only the latest N deltas per context, defined by the `:delta_threshold` configuration.
  - **Periodic Cleanup**: A convenient API for batch cleanup of multiple contexts and deltas.

  ## Configuration
  - `:context_auto_delete` (default: false): Whether to enable automatic context deletion during cleanup.
  - `:context_ttl` (default: nil): Time-to-live for context entries.
  - `:delta_ttl` (default: 24 hours): Time-to-live for deltas.
  - `:delta_threshold` (default: 100): Maximum number of deltas to retain per context.
  - `:backend`: The backend module used for context and delta storage (default: `Knot.Backend.ETS`).

  ## Example Usage
      iex> Knot.Cleanup.periodic_cleanup(limit: 10)
      :ok
  """

  @default_backend Knot.Backend.ETS
  @default_time Knot.Utils.Time
  @default_context_auto_delete false
  @default_context_ttl nil
  @default_delta_ttl :timer.hours(24)
  @default_delta_threshold 100

  @doc """
  Performs periodic cleanup for contexts and deltas.

  This function fetches all contexts and deltas from the backend, checks their times against
  the configured TTL values, and removes stale entries.

  ## Parameters
    - `opts` (Keyword.t): Optional parameters for fetching contexts and deltas. Examples include:
      - `:limit` - Limit the number of contexts or deltas fetched in each call.

  ## Returns
    - `:ok` after performing the cleanup.

  ## Example
      iex> Knot.Cleanup.periodic_cleanup(limit: 10)
      :ok
  """
  @spec periodic_cleanup(keyword()) :: :ok
  def periodic_cleanup(opts \\ []) do
    current_time = time().current_time(:second)

    # Delete contexts (if auto-deletion is enabled)
    cleanup_contexts(current_time, opts)

    # Delete deltas by time (TTL)
    cleanup_deltas_by_time(current_time, opts)

    # Delete deltas exceeding the threshold
    cleanup_deltas_by_threshold(opts)

    :ok
  end

  defp cleanup_contexts(current_time, opts) do
    context_auto_delete =
      Application.get_env(:knot, :context_auto_delete, @default_context_auto_delete)

    if context_auto_delete do
      context_ttl = Application.get_env(:knot, :context_ttl, @default_context_ttl)
      {:ok, contexts} = backend().list_contexts(opts)

      Enum.each(contexts, fn %{context_id: context_id, inserted_at: state_time} ->
        if current_time - state_time > context_ttl do
          backend().delete_context(context_id)
          backend().delete_deltas_for_context(context_id)
        end
      end)
    end
  end

  defp cleanup_deltas_by_time(current_time, opts) do
    delta_ttl = Application.get_env(:knot, :delta_ttl, @default_delta_ttl)
    {:ok, deltas} = backend().list_deltas(opts)

    Enum.each(deltas, fn %{context_id: context_id, inserted_at: delta_time} ->
      if current_time - delta_time > delta_ttl do
        backend().delete_deltas_by_time(context_id, current_time - delta_ttl)
      end
    end)
  end

  defp cleanup_deltas_by_threshold(opts) do
    delta_threshold = Application.get_env(:knot, :delta_threshold, @default_delta_threshold)
    {:ok, deltas} = backend().list_contexts_with_delta_counts(opts)

    Enum.each(deltas, fn %{context_id: context_id, count: delta_count} ->
      if delta_count > delta_threshold do
        backend().delete_deltas_exceeding_threshold(context_id, delta_threshold)
      end
    end)
  end

  @doc false
  defp backend() do
    Application.get_env(:knot, :backend, @default_backend)
  end

  @doc false
  defp time() do
    Application.get_env(:knot, :time, @default_time)
  end
end
