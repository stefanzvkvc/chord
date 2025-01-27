defmodule Chord do
  @moduledoc """
  Chord: A powerful library for managing real-time contexts with efficiency and flexibility.

  The `Chord` module serves as the library's entry point, providing a high-level API for managing contexts, tracking deltas, and integrating with various storage backends.
  It is designed to simplify state synchronization and lifecycle management in real-time applications.

  ## Key Features

  - **Context management**: Create, update, synchronize, and delete contexts seamlessly.
  - **Delta tracking**: Efficiently track changes to minimize data transfer.
  - **Flexible backends**: Built-in support for ETS (in-memory) and Redis (distributed).
  - **Context export**: Easily export contexts to external storage systems.
  - **Customizable cleanup**: Automate or manually clean up expired data.
  - **Partial updates**: Update specific fields within a context.
  - **Context export**: Easily export contexts to external storage.
  - **External context provider**: Restore contexts from external sources as needed.

  ## Configuration

  Chord is highly configurable via the application environment. Below are the available options:

  ```elixir
  config :chord,
    backend: Chord.Backend.ETS,                                     # Backend for storing contexts and deltas (ETS or Redis)
    context_auto_delete: true,                                      # Enable automatic cleanup of expired contexts
    context_ttl: 6 * 60 * 60,                                       # Time-to-live for contexts
    delta_ttl: 3 * 60 * 60,                                         # Time-to-live for deltas
    delta_threshold: 100,                                           # Maximum number of deltas to retain per context
    delta_formatter: Chord.Delta.Formatter.Default,                 # Delta formatter (default or custom)
    time_provider: MyApp.TimeProvider,                              # Custom time provider for timestamps (optional)
    time_unit: :second,                                             # Unit for timestamps (:second or :millisecond)
    export_callback: &MyApp.ContextExporter.export/1,               # Callback for exporting contexts (optional)
    context_external_provider: &MyApp.ExternalState.fetch_context/1 # Restore contexts from external storage (optional)
  ```

  ## Common Options

  The following options are shared across several functions in this module and related modules:

    - :context_id - The identifier for the context.
    - :version - The version number for tracking state changes.
    - :inserted_at - The timestamp when the context or delta was created.
    - :limit - The maximum number of contexts or deltas to fetch.
    - :offset - The number of entries to skip when fetching.
    - :order - The sort order for results (:asc or :desc).
  """

  alias Chord.{Context, Cleanup}

  # Context Management API

  @doc """
  Sets the global context and records deltas.

  This function allows you to set a new global context for a specific identifier
  and automatically calculates deltas for any changes.

  ## Parameters
    - `context_id` (any): The identifier for the context. This should uniquely represent the context.
    - `new_context` (map): The new context to be stored. This should be a map containing the desired state.

  ## Returns
    - `{:ok, %{context: map(), delta: map()}}` on success.
    - `{:error, term()}` on failure.

  ## Examples
      iex> Chord.set_context("user:369", %{status: "online", metadata: %{theme: "light", language: "en-US"}})
      {:ok,
      %{
        context: %{
          version: 1,
          context: %{
            status: "online",
            metadata: %{language: "en-US", theme: "light"}
          },
          context_id: "user:369",
          inserted_at: 1737892321
        },
        delta: %{
          version: 1,
          context_id: "user:369",
          delta: %{
            status: %{value: "online", action: :added},
            metadata: %{
              language: %{value: "en-US", action: :added},
              theme: %{value: "light", action: :added}
            }
          },
          inserted_at: 1737892321
        }
      }}
  """
  @spec set_context(context_id :: any(), new_context :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate set_context(context_id, new_context), to: Context.Manager

  @doc """
  Retrieves the current global context for a given identifier.

  This function fetches the context associated with the given `context_id`. If the context
  does not exist or an invalid `context_id` is provided, an error is returned.

  ## Parameters
    - `context_id` (any): The identifier for the context. This should uniquely represent the context.

  ## Returns
    - `{:ok, map()}` on success, where the map contains the context data.
    - `{:error, :not_found}` if the context does not exist.
    - `{:error, term()}` for other types of failures.

  ## Examples
      iex> Chord.get_context("user:369")
      {:ok,
      %{
        version: 1,
        context: %{status: "online", metadata: %{language: "en-US", theme: "light"}},
        context_id: "user:369",
        inserted_at: 1737892321
      }}

      iex> Chord.get_context("user:non-existent")
      {:error, :not_found}
  """
  @spec get_context(context_id :: any()) :: {:ok, map()} | {:error, term()}
  defdelegate get_context(context_id), to: Context.Manager

  @doc """
  Partially updates the global context for a given identifier.

  This function applies the given changes to the existing context identified by `context_id`.
  It calculates the delta for the updated fields and returns the updated context and delta.

  ## Parameters
    - `context_id` (any): The identifier for the context. This should uniquely represent the context.
    - `changes` (map):  A map of fields to be updated in the existing context.
      The keys in this map must correspond to valid fields in the context, or,
      if a specified path does not exist, it will be added as a new field at the root level of the context.

  ## Returns
    - `{:ok, %{context: map(), delta: map()}}` on success, where:
      - `context` is the updated context.
      - `delta` is a map representing the changes made.
    - `{:error, :not_found}` if the context does not exist.
    - `{:error, term()}` for other types of failures.

  ## Examples
      iex> Chord.update_context("user:369", %{metadata: %{theme: "dark"}})
      {:ok,
      %{
        context: %{
          version: 2,
          context: %{status: "online", metadata: %{language: "en-US", theme: "dark"}},
          context_id: "user:369",
          inserted_at: 1737893007
        },
        delta: %{
          version: 2,
          context_id: "user:369",
          delta: %{
            metadata: %{
              theme: %{value: "dark", action: :modified, old_value: "light"}
            }
          },
          inserted_at: 1737893007
        }
      }}

      iex> Chord.update_context("user:non-existent", %{metadata: %{theme: "dark"}})
      {:error, :not_found}
  """
  @spec update_context(context_id :: any(), changes :: map()) :: {:ok, map()} | {:error, term()}
  defdelegate update_context(context_id, changes), to: Context.Manager

  @doc """
  Restores a context from an external provider to the current backend.

  This function retrieves a context from an external storage provider (e.g., a database or cloud storage)
  and stores it in the current backend for future use.

  ## Parameters
    - `context_id` (any): The identifier for the context. This should uniquely represent the context.

  ## Returns
    - `{:ok, map()}` on success, where the map represents the restored context.
    - `{:error, :not_found}` if the context is not found in the external storage.
    - `{:error, term()}` for other types of failures.

  ## Examples
      iex> Chord.restore_context("user:369")
      {:ok,
      %{
        version: 10,
        context: %{source: "external storage provider"},
        inserted_at: 1737464001,
        context_id: "user:369"
      }}

      iex> Chord.restore_context("user:non-existent")
      {:error, :not_found}
  """
  @spec restore_context(context_id :: any()) :: {:ok, map()} | {:error, term()}
  defdelegate restore_context(context_id), to: Context.Manager

  @doc """
  Deletes the global context, including all associated deltas.

  This function removes the context identified by `context_id` from the backend, along with
  all deltas related to that context. Once deleted, the context cannot be restored unless it is backed up externally.

  ## Parameters
    - `context_id` (any): The identifier for the context. This should uniquely represent the context.

  ## Returns
    - `:ok` on success, confirming that the context and its deltas were deleted.
    - `{:error, term()}` for other types of failures.

  ## Examples
      iex> Chord.delete_context("user:369")
      :ok

      iex> Chord.delete_context("user:non-existent")
      {:error, :not_found}
  """
  @spec delete_context(context_id :: any()) :: :ok | {:error, term()}
  defdelegate delete_context(context_id), to: Context.Manager

  @doc """
  Exports the active context for a given identifier to external storage using the configured export callback.

  This function retrieves the current context for the specified `context_id` and sends it
  to an external storage provider via the callback defined in the application configuration.

  ## Parameters
    - `context_id` (any): The identifier for the context. This should uniquely represent the context.

  ## Returns
    - `:ok` if the context is successfully exported to the external storage.
    - `{:error, :not_found}` if the specified context does not exist.
    - `{:error, term()}` for other types of failures.

  ## Examples
      iex> Chord.export_context("user:123")
      :ok

      iex> Chord.export_context("user:non-existent")
      {:error, :not_found}
  """
  @spec export_context(context_id :: any()) :: :ok | {:error, term()}
  defdelegate export_context(context_id), to: Context.Manager

  @doc """
  Synchronizes the context for a client based on its current version.

  This function ensures that the client has the latest version of the context identified by `context_id`.
  Depending on the client's version, it will return either the full context, the delta of changes, or indicate
  that no synchronization is necessary.

  ## Parameters
    - `context_id` (any): The identifier for the context. This should uniquely represent the context.
    - `client_version` (integer): The last known version of the context for the client.

  ## Returns
    - `{:full_context, map()}`: Returns the entire context if the client is too far behind or has no version.
    - `{:delta, map()}`: Returns only the changes (deltas) required to update the client to the latest version.
    - `{:no_change, version}`: Indicates that the client's version is already up-to-date and no synchronization is needed.

  ## Examples
      iex> Chord.sync_context("user:369", nil)
      {:full_context,
      %{
        version: 2,
        context: %{status: "online", metadata: %{language: "en-US", theme: "dark"}},
        context_id: "user:369",
        inserted_at: 1737893007
      }}

      iex> Chord.sync_context("user:369", 1)
      {:delta,
      %{
        version: 2,
        context_id: "user:369",
        delta: %{
          metadata: %{theme: %{value: "dark", action: :modified, old_value: "light"}}
        },
        inserted_at: 1737893007
      }}

      iex> Chord.sync_context("user:369", 2)
      {:no_change, 2}
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

  ## Examples
      iex> Chord.cleanup(limit: 10)
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
    - `{:error, reason}` if an error occurs when starting the cleanup server process.

  ## Examples
      iex> Chord.start_cleanup_server(interval: 60000)
      {:ok, #PID<0.247.0>}
  """
  @spec start_cleanup_server(opts :: Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_cleanup_server(opts \\ []) do
    Cleanup.Server.start_link(opts)
  end

  @doc """
  Stops the Cleanup.Server if running.

  ## Returns
    - `:ok` on success.

  ## Examples
      iex> Chord.stop_cleanup_server()
      :ok
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

  ## Returns
    - `:ok` on success.

  ## Examples
      iex> Chord.update_cleanup_interval(30000)
      :ok
  """
  @spec update_cleanup_interval(new_interval :: integer()) :: :ok
  def update_cleanup_interval(new_interval) do
    Cleanup.Server.update_interval(new_interval)
  end

  @doc """
  Updates the backend options for the cleanup server at runtime.

  ## Parameters
    - `new_opts` (Keyword.t): The new backend options.

  ## Returns
    - `:ok` on success.

  ## Examples
      iex> Chord.update_cleanup_backend_opts([limit: 100])
      :ok
  """
  @spec update_cleanup_backend_opts(new_opts :: Keyword.t()) :: :ok
  def update_cleanup_backend_opts(new_opts) do
    Cleanup.Server.update_backend_opts(new_opts)
  end
end
