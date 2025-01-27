defmodule Chord.Cleanup do
  @moduledoc """
  This module provides functionality to clean up data that is no longer needed,
  such as old contexts or deltas, ensuring efficient use of storage and memory.

  ## Key Features
  - **Time-based cleanup**: Periodically remove stale contexts or deltas based on configurable time-to-live (TTL) values.
  - **Threshold-based cleanup**: Retain only the latest N deltas per context, defined by the `:delta_threshold` configuration.
  - **Periodic cleanup**: A convenient API for batch cleanup of multiple contexts and deltas.

  ## Configuration
  - `:context_auto_delete` (default: false): Whether to enable automatic context deletion during cleanup.
  - `:context_ttl` (default: nil): Time-to-live for context entries.
  - `:delta_ttl` (default: 24 hours): Time-to-live for deltas.
  - `:delta_threshold` (default: 100): Maximum number of deltas to retain per context.
  - `:backend`: The backend module used for context and delta storage (default: `Chord.Backend.ETS`).

  ## Example Usage
      iex> Chord.Cleanup.periodic_cleanup(limit: 10)
      :ok
  """

  require Logger

  @default_backend Chord.Backend.ETS
  @default_time_provider Chord.Utils.Time
  @default_time_unit :second
  @default_context_auto_delete false
  @default_context_ttl nil
  @default_delta_ttl 24 * 60 * 60
  @default_delta_threshold 100

  @doc """
  Performs periodic cleanup for contexts and deltas.

  This function fetches all contexts and deltas from the backend, checks their times against
  the configured TTL values, and removes stale entries.

  ## Parameters
    - `opts` (Keyword.t): Optional parameters for fetching contexts and deltas (see "Common Options" in the `Chord` module).

  ## Returns
    - `:ok` after performing the cleanup.

  ## Example
      iex> Chord.Cleanup.periodic_cleanup(limit: 10)
      :ok
  """
  @spec periodic_cleanup(keyword()) :: :ok
  def periodic_cleanup(opts \\ []) do
    time_unit = time_unit()
    current_time = time_provider().current_time(time_unit)
    Logger.info("Starting periodic cleanup at #{current_time} with options: #{inspect(opts)}")

    # Delete contexts (if auto-deletion is enabled)
    cleanup_contexts(current_time, opts)

    # Delete deltas by time (TTL)
    cleanup_deltas_by_time(current_time, opts)

    # Delete deltas exceeding the threshold
    cleanup_deltas_by_threshold(opts)

    Logger.info("Periodic cleanup completed at #{System.system_time(time_unit)}")

    :ok
  end

  defp cleanup_contexts(current_time, opts) do
    context_auto_delete = context_auto_delete()
    context_ttl = context_ttl()

    if context_auto_delete && context_ttl do
      Logger.info("Cleaning up contexts older than #{context_ttl}")

      {:ok, contexts} = backend().list_contexts(opts)

      Enum.each(contexts, fn %{
                               context_id: context_id,
                               inserted_at: state_time
                             } ->
        if current_time - state_time > context_ttl do
          Logger.debug("Cleaning up context #{context_id}, last modified at #{state_time}")

          with :ok <- backend().delete_context(context_id),
               :ok <- backend().delete_deltas_for_context(context_id) do
            Logger.info("Context #{inspect(context_id)} and related deltas successfully deleted")
          else
            error ->
              Logger.error("Failed to delete context #{inspect(context_id)}: #{inspect(error)}")
          end
        else
          Logger.debug("Skipping context #{context_id}, within TTL.")
        end
      end)
    else
      Logger.debug("Context auto-deletion is disabled or TTL is not set.")
    end
  end

  defp cleanup_deltas_by_time(current_time, opts) do
    delta_ttl = delta_ttl()

    if delta_ttl do
      Logger.info("Cleaning up deltas older than #{delta_ttl}")

      {:ok, deltas} = backend().list_deltas(opts)

      Enum.each(deltas, fn %{context_id: context_id, inserted_at: delta_time} ->
        if current_time - delta_time > delta_ttl do
          Logger.debug(
            "Cleaning up deltas for context #{context_id}, last modified at #{delta_time}"
          )

          result = backend().delete_deltas_by_time(context_id, current_time - delta_ttl)

          case result do
            :ok ->
              Logger.info("Deltas for context #{inspect(context_id)} successfully deleted")

            error ->
              Logger.error("Delta cleanup failed with error: #{inspect(error)}")
          end
        else
          Logger.debug("Skipping deltas for context #{context_id}, within TTL.")
        end
      end)
    else
      Logger.debug("Delta TTL is not set; skipping delta cleanup.")
    end
  end

  defp cleanup_deltas_by_threshold(opts) do
    delta_threshold = delta_threshold()

    if delta_threshold do
      Logger.info("Cleaning up deltas exceeding the threshold of #{delta_threshold}")

      {:ok, deltas} = backend().list_contexts_with_delta_counts(opts)

      Enum.each(deltas, fn %{context_id: context_id, count: delta_count} ->
        if delta_count > delta_threshold do
          Logger.debug("Deleting excess deltas for context #{context_id}, count: #{delta_count}")

          case backend().delete_deltas_exceeding_threshold(context_id, delta_threshold) do
            :ok ->
              Logger.info("Excess deltas for context #{inspect(context_id)} successfully deleted")

            error ->
              Logger.error(
                "Failed to delete excess deltas for context #{inspect(context_id)}: #{inspect(error)}"
              )
          end
        else
          Logger.debug("Skipping context #{context_id}, delta count within threshold.")
        end
      end)
    else
      Logger.debug("Delta threshold is not set; skipping threshold-based cleanup.")
    end
  end

  defp backend() do
    Application.get_env(:chord, :backend, @default_backend)
  end

  defp time_provider() do
    Application.get_env(:chord, :time_provider, @default_time_provider)
  end

  defp time_unit() do
    Application.get_env(:chord, :time_unit, @default_time_unit)
  end

  defp context_auto_delete() do
    Application.get_env(:chord, :context_auto_delete, @default_context_auto_delete)
  end

  defp context_ttl() do
    Application.get_env(:chord, :context_ttl, @default_context_ttl)
  end

  defp delta_ttl() do
    Application.get_env(:chord, :delta_ttl, @default_delta_ttl)
  end

  defp delta_threshold() do
    Application.get_env(:chord, :delta_threshold, @default_delta_threshold)
  end
end
