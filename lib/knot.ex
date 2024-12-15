defmodule Knot do
  @moduledoc """
  Knot: Synchronize and manage contexts with ease.
  A versatile library that provides delta tracking, efficient cleanup, and backend flexibility for real-time applications.

  This module serves as the entry point for using Knot's core functionalities. It abstracts
  the complexities of context and delta management, cleanup operations, and backend integration.

  ## Features

    - Global context and delta synchronization.
    - Flexible backends with built-in ETS support.
    - Customizable delta formatting.
    - Customizable time providing.
    - Periodic cleanup with an optional Knot.Cleanup.Server.

  ## Configuration

  Knot can be configured via the application environment:

      config :knot,
        backend: Knot.Backend.ETS,
        context_auto_delete: true,
        context_ttl: :timer.hours(6),
        delta_ttl: :timer.hours(3),
        delta_threshold: 100,
        delta_formatter: Knot.Delta.Formatter.Default,
        time: MyCustomTimeProvider

  """

  alias Knot.{Context, Cleanup}

  # Context Management API

  @doc """
  Sets the global context and records deltas.

  ## Parameters

    - `context_id` - The identifier for the context.
    - `new_context` - The new context to be stored.

  ## Returns

  - `{:ok, {new_context, delta, version}}` on success.

  """
  @spec set_context(context_id :: any(), new_context :: map()) :: {:ok, {map(), map(), integer()}}
  defdelegate set_context(context_id, new_context), to: Context.Manager

  @doc """
  Retrieves the current global context and version for a given identifier.

  ## Parameters

    - `context_id` - The identifier for the context.

  ## Returns

  - `{:ok, {context, version}}` where `context` is the current global context and `version` is the version number.

  """
  @spec get_context(any()) :: {:ok, {map(), integer()}} | {:error, term()}
  defdelegate get_context(context_id), to: Context.Manager

  @doc """
  Synchronizes the context for a client based on its current version.

  ## Parameters

    - `context_id` - The identifier for the context.
    - `client_version` - The last known version for the client.

  ## Returns

  - `{:full_context, context, version}` if a full context is sent.
  - `{:delta, delta, version}` if deltas are sent.
  - `{:no_change, version}` if no changes are needed.

  """
  @spec sync_context(context_id :: any(), client_version :: integer() | nil) ::
          {:full_context, map(), integer()} | {:delta, map(), integer()} | {:no_change, integer()}
  defdelegate sync_context(context_id, client_version), to: Context.Manager

  @doc """
  Deletes the global context, including all deltas.

  ## Parameters

    - `context_id` - The identifier for the context.

  ## Returns

  - `:ok` on success.
  """
  @spec delete_context(any()) :: :ok | {:error, term()}
  defdelegate delete_context(context_id), to: Context.Manager

  # Cleanup API

  @doc """
  Triggers a one-time cleanup for stale contexts and deltas.

  ## Parameters

    - `opts` - Keyword options to filter contexts (e.g., `limit`, `offset`).

  ## Returns

  - `:ok` on success.
  """
  @spec cleanup(Keyword.t()) :: :ok
  def cleanup(opts \\ []) do
    Cleanup.periodic_cleanup(opts)
  end

  # CleanupServer Management API

  @doc """
  Starts the Cleanup.Server for periodic cleanup.

  ## Parameters

    - `opts` - Options for the Cleanup.Server (e.g., `interval`, `backend_opts`).

  ## Returns

  - `{:ok, pid}` on success.

  """
  @spec start_cleanup_server(Keyword.t()) :: {:ok, pid()} | {:error, term()}
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
end
