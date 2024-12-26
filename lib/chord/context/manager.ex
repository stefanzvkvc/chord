defmodule Chord.Context.Manager do
  @moduledoc """
  Orchestrates context synchronization, delta calculation, and backend interactions.

  The `Chord.Context.Manager` module is responsible for the core operations in Chord,
  including context management, delta tracking, and backend interactions. It provides
  a flexible and efficient system for managing state and deltas, designed to work seamlessly
  with in-memory or external backends, offering users customizable workflows for their specific needs.

  ## Features

  - **Context Management:** Handles retrieval, updates, and deletions of contexts efficiently.
  - **Delta Tracking:** Automatically calculates and stores deltas between context updates.
  - **Synchronization:** Supports syncing contexts and deltas to clients based on their known versions.
  - **Exporting Contexts:** Allows exporting active contexts to external storage using a configurable callback.
  - **Flexible Backends:** Compatible with built-in ETS or Redis backends, as well as custom backends.
  - **External Context Integration:** Supports fetching contexts from external storage when needed.

  ## Use Cases

  This module is designed for applications where efficient state and delta management
  is critical, such as:

  - Real-time collaborative applications (e.g., document editing, multiplayer games).
  - Communication platforms (e.g., chat systems, call management).
  - Systems requiring versioned state synchronization.

  Developers can leverage `Chord.Context.Manager` to manage contexts with minimal boilerplate,
  while retaining the flexibility to adapt the behavior through configuration and callbacks.

  ## Configuration

  The behavior of this module is driven by the following configuration options:

      config :chord,
        backend: Chord.Backend.ETS, # Backend to use for storing contexts and deltas.
        delta_threshold: 100, # Threshold for determining when to send full contexts.
        export_callback: &MyApp.ContextExporter.export/1, # Callback for exporting contexts.
        context_external_provider: &MyApp.ExternalProvider.fetch_context/1 # Function for fetching external contexts.

  """

  require Logger
  alias Chord.Delta
  alias Chord.Utils.Context.MapTransform
  @default_backend Chord.Backend.ETS
  @default_delta_threshold 100

  # Public API

  @doc """
  Updates the global context for a given identifier and calculates deltas.

  ## Parameters
    - `context_id` (any): The ID of the context to update.
    - `new_context` (map): The full updated context to set.

  ## Returns
    - `{:ok, %{context: map(), delta: map()}}` on success.
    - `{:error, term()}` on failure.
  """
  @spec set_context(context_id :: any(), new_context :: map()) :: {:ok, map()} | {:error, term()}
  def set_context(context_id, new_context) do
    Logger.debug("Setting context for #{inspect(context_id)}")

    %{context: old_context, version: old_version} = get_or_initialize_context(context_id)

    log_existing_context(context_id, old_context, old_version)

    case calculate_and_process_delta(context_id, old_context, old_version, new_context) do
      {:ok, result} ->
        Logger.info("Context for #{inspect(context_id)} updated successfully")
        {:ok, result}

      {:skip, result} ->
        Logger.debug("No changes detected for context #{inspect(context_id)}. Skipping update.")
        {:ok, result}

      {:error, reason} ->
        Logger.error("Failed to set context for #{inspect(context_id)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Retrieves the current context for a given identifier.

  ## Parameters
    - `context_id` (any): The ID of the context to be retrieved.

  ## Returns
    - `{:ok, map()}` if context exists.
    - `{:error, term()}` if no context is available.
  """
  @spec get_context(context_id :: any()) :: {:ok, map()} | {:error, term()}
  def get_context(context_id) do
    Logger.debug("Fetching context for ID: #{inspect(context_id)}")

    case backend().get_context(context_id) do
      {:ok, context} ->
        Logger.info("Successfully fetched context for ID: #{inspect(context_id)}")
        {:ok, context}

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch context for ID: #{inspect(context_id)}. Reason: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Partially updates the context for a given identifier and calculates deltas.

  Only the provided fields in `changes` are updated in the existing context.

  ## Parameters
    - `context_id` (any): The ID of the context to update.
    - `changes` (map): A map of fields to be updated.

  ## Returns
    - `{:ok, %{context: map(), delta: map()}}` on success.
    - `{:error, term()}` on failure.
  """
  @spec update_context(context_id :: any(), changes :: map()) :: {:ok, map()} | {:error, term()}
  def update_context(context_id, changes) do
    Logger.debug("Updating context for #{inspect(context_id)} with changes: #{inspect(changes)}")

    case backend().get_context(context_id) do
      {:ok, %{context: old_context, version: old_version}} ->
        log_existing_context(context_id, old_context, old_version)

        updated_context = MapTransform.deep_update(old_context, changes)

        case calculate_and_process_delta(context_id, old_context, old_version, updated_context) do
          {:ok, result} ->
            Logger.info("Context for #{inspect(context_id)} updated successfully")
            {:ok, result}

          {:skip, result} ->
            Logger.debug(
              "No changes detected for context #{inspect(context_id)}. Skipping update."
            )

            {:ok, result}

          {:error, reason} ->
            Logger.error("Failed to set context for #{inspect(context_id)}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, _error} = error ->
        Logger.error("Failed to update context for #{inspect(context_id)}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Restores a context from an external provider to the current backend.

  ## Parameters
    - `context_id` (any): The ID of the context to restore.

  ## Returns
    - `{:ok, map()}` on success.
    - `{:error, :not_found}` if the context is missing in external storage.
  """
  @spec restore_context(context_id :: any()) :: {:ok, map()} | {:error, :not_found}
  def restore_context(context_id) do
    Logger.debug("Restoring context for #{inspect(context_id)} from external provider")

    case get_context_from_external_storage(context_id) do
      {:ok, %{context: context, version: version}} ->
        Logger.info(
          "Successfully fetched context for #{inspect(context_id)} from external provider"
        )

        backend().set_context(context_id, context, version)

      error ->
        Logger.error("Failed to restore context for #{inspect(context_id)}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Deletes the context and its associated deltas.

  ## Parameters
    - `context_id` (any): The ID of the context to delete.

  ## Returns
    - `:ok` on success.
    - `{:error, term()}` on failure.
  """
  @spec delete_context(context_id :: any()) :: :ok | {:error, term()}
  def delete_context(context_id) do
    Logger.debug("Deleting context and deltas for #{inspect(context_id)}")

    with :ok <- backend().delete_context(context_id),
         :ok <- backend().delete_deltas_for_context(context_id) do
      Logger.info("Successfully deleted context and deltas for #{inspect(context_id)}")

      :ok
    else
      error ->
        Logger.error(
          "Failed to delete context or deltas for #{inspect(context_id)}: #{inspect(error)}"
        )

        error
    end
  end

  @doc """
  Exports the context for a given identifier to an external storage.

  ## Parameters
    - `context_id` (any): The ID of the context to export.

  ## Returns
    - `:ok` on success.
    - `{:error, :not_found}` if the context does not exist.
  """
  @spec export_context(context_id :: any()) :: :ok | {:error, :not_found}
  def export_context(context_id) do
    Logger.debug("Exporting context for #{inspect(context_id)}")

    with {:ok, context} <- backend().get_context(context_id),
         :ok <- call_export_callback(context) do
      Logger.info("Successfully exported context for #{inspect(context_id)}")

      :ok
    else
      error ->
        Logger.error(
          "Failed to export context or deltas for #{inspect(context_id)}: #{inspect(error)}"
        )

        error
    end
  end

  @doc """
  Synchronizes the context for a specific identifier.

  Determines whether the client receives the full context, deltas, or no changes
  based on the client's known version.

  ## Parameters
    - `context_id` (any): The ID of the context to synchronize.
    - `client_version` (integer | nil): The version of the context known to the client.

  ## Returns
    - `{:full_context, map()}` if the client should receive the full context.
    - `{:delta, map()}` if the client should receive deltas.
    - `{:no_change, integer()}` if the client has the latest version.
  """
  @spec sync_context(context_id :: any(), client_version :: integer() | nil) ::
          {:full_context, map()} | {:delta, map()} | {:no_change, integer()} | {:error, term()}
  def sync_context(context_id, client_version) do
    Logger.debug(
      "Synchronizing context for #{inspect(context_id)} with client version #{inspect(client_version)}"
    )

    case backend().get_context(context_id) do
      {:ok, %{version: version} = context} ->
        sync_action = determine_sync_action(client_version, version)
        Logger.debug("Determined sync action: #{inspect(sync_action)}")

        case sync_action do
          :full_context ->
            Logger.debug("Sending full context for #{inspect(context_id)}")

            {:full_context, context}

          :no_change ->
            Logger.debug("No changes needed for #{inspect(context_id)}")

            {:no_change, version}

          :deltas ->
            Logger.debug("Sending deltas for #{inspect(context_id)}")

            sync_deltas_or_fallback(context_id, context, client_version)
        end

      {:error, _error} = error ->
        Logger.error("Failed to sync context for #{inspect(context_id)}: #{inspect(error)}")
        error
    end
  end

  # Private Helpers

  defp sync_deltas_or_fallback(context_id, context, client_version) do
    case backend().get_deltas(context_id, client_version) do
      {:ok, delta} ->
        delta = Delta.merge_deltas(delta)
        {:delta, delta}

      _ ->
        {:full_context, context}
    end
  end

  defp get_or_initialize_context(context_id) do
    case backend().get_context(context_id) do
      {:error, :not_found} -> %{context: %{}, version: 0}
      {:ok, context} -> context
    end
  end

  defp calculate_and_process_delta(context_id, old_context, old_version, new_context) do
    delta = Delta.calculate_delta(old_context, new_context)

    if delta == %{} do
      {:skip, %{context: old_context, delta: delta}}
    else
      process_update(context_id, new_context, old_version, delta)
    end
  end

  defp process_update(context_id, new_context, old_version, delta) do
    new_version = old_version + 1
    Logger.debug("Delta calculated: #{inspect(delta)}")

    with {:ok, context} <- backend().set_context(context_id, new_context, new_version),
         {:ok, delta} <- backend().set_delta(context_id, delta, new_version) do
      {:ok, %{context: context, delta: delta}}
    else
      error -> {:error, error}
    end
  end

  defp get_context_from_external_storage(context_id) do
    context_external_provider = context_external_provider()

    if is_function(context_external_provider, 1) do
      context_external_provider.(context_id)
    else
      {:error, :no_context_external_provider}
    end
  end

  defp determine_sync_action(client_version, current_version) do
    cond do
      client_version == nil -> :full_context
      client_version < current_version - delta_threshold() -> :full_context
      client_version >= current_version -> :no_change
      true -> :deltas
    end
  end

  defp call_export_callback(context) do
    export_callback = export_callback()

    if is_function(export_callback, 1) do
      export_callback.(context)
    else
      {:error, :no_export_callback}
    end
  end

  defp log_existing_context(context_id, old_context, old_version) do
    Logger.debug("""
    Old context for #{inspect(context_id)}:
    Context: #{inspect(old_context)}
    Version: #{inspect(old_version)}
    """)
  end

  # Configuration

  defp backend(), do: Application.get_env(:chord, :backend, @default_backend)
  defp export_callback(), do: Application.get_env(:chord, :export_callback)
  defp context_external_provider(), do: Application.get_env(:chord, :context_external_provider)

  defp delta_threshold(),
    do: Application.get_env(:chord, :delta_threshold, @default_delta_threshold)
end
