defmodule Chord do
  @moduledoc """
  Chord: A powerful library for managing real-time contexts with efficiency and flexibility.

  The Chord module serves as the entry point for the library, providing a high-level API
  to manage contexts, deltas, cleanup, and integrations with various storage backends.
  It simplifies state synchronization and lifecycle management for real-time applications.

  ## Key Features

  - **Context Management**: Create, update, synchronize, and delete application contexts.
  - **Delta Tracking**: Efficiently track changes to minimize data transfer.
  - **Flexible Backends**: Support for in-memory (ETS) and distributed (Redis) storage.
  - **Context Export**: Easily export contexts to external storage.
  - **Customizable Cleanup**: Automated or manual cleanup of expired data.
  - **Partial Updates**: Apply updates to specific fields within a context.
  - **External Context Provider**: Restore contexts from external sources when needed.

  ## Configuration

  Chord is designed to be configurable via the application environment. Below are the
  configuration options available:

      config :chord,
        backend: Chord.Backend.ETS, # Backend for storing contexts and deltas (ETS or Redis)
        context_auto_delete: true, # Automatically delete expired contexts
        context_ttl: :timer.hours(6), # Time-to-live for contexts
        delta_ttl: :timer.hours(3), # Time-to-live for deltas
        delta_threshold: 100, # Maximum number of deltas to retain per context
        delta_formatter: Chord.Delta.Formatter.Default, # Formatter for deltas
        time_provider: MyApp.TimeProvider, # Custom time provider for timestamping
        export_callback: &MyApp.ContextExporter.export/1, # Callback for exporting contexts
        context_external_provider: &MyApp.ExternalState.fetch_context/1 # Restore context from external storage

  ## Common Options

  The following options are shared across several functions in this module and related modules:

    - :context_id - The identifier for the context.
    - :version - The version number for tracking state changes.
    - :inserted_at - The timestamp when the context or delta was created.
    - :limit - The maximum number of contexts or deltas to fetch.
    - :offset - The number of entries to skip when fetching.
    - :order - The sort order for results (:asc or :desc).

  ## Example Usage

  Here's how you can use Chord in your application:

      # Set a context
      {:ok, %{context: updated_context, delta: delta}} =
        Chord.set_context("call:123", %{status: "active"})

      # Get the current context
      {:ok, %{context_id: context_id, context: context, version: version, inserted_at: inserted_at}} = Chord.get_context("call:123")

      # Apply a partial update to a context
      {:ok, %{context: updated_context, delta: delta}} =
        Chord.update_context("call:123", %{status: "ended"})

      # Synchronize context with a client
      case Chord.sync_context("call:123", client_version) do
        {:full_context, context} -> :send_full_context
        {:delta, delta} -> :send_delta
        {:no_change, version} -> :no_change
      end

      # Restore a context from external storage
      {:ok, context_data} = Chord.restore_context("call:123")

      # Export a context to external storage
      :ok = Chord.export_context("call:123")

      # Trigger cleanup
      Chord.cleanup(limit: 10)

      # Start the Cleanup.Server for periodic cleanup
      {:ok, _pid} = Chord.start_cleanup_server(interval: :timer.minutes(30))

  """

  alias Chord.{Context, Cleanup}

  # Context Management API

  @doc """
  Sets the global context and records deltas.

  ## Parameters

    - `context_id` - The identifier for the context.
    - `new_context` - The new context to be stored.

  ## Returns

  - `{:ok, %{context: map(), delta: map()}}` on success.
  - `{:error, term()}` on failure.
  """
  @spec set_context(context_id :: any(), new_context :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate set_context(context_id, new_context), to: Context.Manager

  @doc """
  Retrieves the current global context for a given identifier.

  ## Parameters

    - `context_id` - The identifier for the context.

  ## Returns

  - `{:ok, map()}` on success.
  - `{:error, term()}` on failure.
  """
  @spec get_context(context_id :: any()) :: {:ok, map()} | {:error, term()}
  defdelegate get_context(context_id), to: Context.Manager

  @doc """
  Partially updates the global context for a given identifier.

  ## Parameters

    - `context_id` - The identifier for the context.
    - `changes` - A map of fields to be updated in the existing context.

  ## Returns

  - `{:ok, %{context: map(), delta: map()}}` on success.
  - `{:error, term()}` on failure.
  """
  @spec update_context(context_id :: any(), changes :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate update_context(context_id, changes), to: Context.Manager

  @doc """
  Restores a context from an external provider to the current backend.

  ## Parameters
    - `context_id` (any): The ID of the context to restore.

  ## Returns
    - `{:ok, map()}` on success.
    - `{:error, :not_found}` if the context is missing in external storage.
  """
  @spec restore_context(context_id :: any()) :: {:ok, map()} | {:error, :not_found}
  defdelegate restore_context(context_id), to: Context.Manager

  @doc """
  Deletes the global context, including all deltas.

  ## Parameters

    - `context_id` - The identifier for the context.

  ## Returns

  - `:ok` on success.
  """
  @spec delete_context(context_id :: any()) :: :ok | {:error, term()}
  defdelegate delete_context(context_id), to: Context.Manager

  @doc """
  Exports the active context for a given identifier to external storage using the configured export callback.

  ## Parameters

    - `context_id` - The identifier for the context.

  ## Returns

  - `:ok` if the context is successfully exported.
  - `{:error, :not_found}` if the context does not exist.
  """
  @spec export_context(context_id :: any()) :: :ok | {:error, :not_found}
  defdelegate export_context(context_id), to: Context.Manager

  @doc """
  Synchronizes the context for a client based on its current version.

  ## Parameters

    - `context_id` - The identifier for the context.
    - `client_version` - The last known version for the client.

  ## Returns

  - `{:full_context, map()}` if a full context is sent.
  - `{:delta, map()}` if deltas are sent.
  - `{:no_change, version}` if no changes are needed.
  """
  @spec sync_context(context_id :: any(), client_version :: integer() | nil) ::
          {:full_context, map()} | {:delta, map()} | {:no_change, integer()}
  defdelegate sync_context(context_id, client_version), to: Context.Manager

  # Cleanup API

  @doc """
  Triggers a one-time cleanup for stale contexts and deltas.

  ## Parameters

    - `opts` (Keyword.t): Optional parameters for filtering contexts and deltas (see "Common Options").

  ## Returns

  - `:ok` on success.
  """
  @spec cleanup(opts :: Keyword.t()) :: :ok
  def cleanup(opts \\ []) do
    Cleanup.periodic_cleanup(opts)
  end

  # Cleanup.Server Management API

  @doc """
  Starts the Cleanup.Server for periodic cleanup.

  ## Parameters

    - `opts` - Options for the Cleanup.Server. Examples include:
      - `:interval` - The interval (in milliseconds) between cleanup executions.
      - `:backend_opts` - A keyword list of options passed to backend listing functions (see "Common Options").

  ## Returns

  - `{:ok, pid}` on success.
  """
  @spec start_cleanup_server(opts :: Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_cleanup_server(opts \\ []) do
    Cleanup.Server.start_link(opts)
  end

  @doc """
  Stops the CleanupServer if running.

  ## Returns

  - `:ok` on success.
  """
  @spec stop_cleanup_server() :: :ok
  def stop_cleanup_server do
    case Process.whereis(Cleanup.Server) do
      nil -> :ok
      pid -> GenServer.stop(pid, :normal)
    end
  end

  @doc """
  Updates the cleanup server's interval at runtime.

  ## Parameters
    - `new_interval` (integer): The new interval in milliseconds.
  """
  @spec update_cleanup_interval(new_interval :: integer()) :: :ok
  def update_cleanup_interval(new_interval) do
    Cleanup.Server.update_interval(new_interval)
  end

  @doc """
  Updates the backend options for the cleanup server at runtime.

  ## Parameters
    - `new_opts` (Keyword.t): The new backend options.
  """
  @spec update_cleanup_backend_opts(new_opts :: Keyword.t()) :: :ok
  def update_cleanup_backend_opts(new_opts) do
    Cleanup.Server.update_backend_opts(new_opts)
  end
end
