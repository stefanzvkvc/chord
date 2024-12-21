defmodule Chord.Backend.Behaviour do
  @moduledoc """
  Defines the behavior for backends used by Chord.

  This module specifies the contract that any backend implementation must adhere to.
  It provides a consistent interface for managing context and delta data, supporting
  operations for context storage, delta tracking, and cleanup.

  ## Key Concepts

  - **Context Operations:** Manage context data associated with a unique `context_id`.
  - **Delta Operations:** Track and retrieve changes (deltas) associated with contexts.
  - **Listing Operations:** Enable filtering and listing of contexts and deltas.
  - **Cleanup:** Support for deleting old or unnecessary data to maintain performance.

  Developers can implement this behavior to provide custom backends (e.g., Redis, Database).

  ## Example Usage

  To implement a custom backend, define a module and implement the callbacks specified here:

      defmodule MyApp.CustomBackend do
        @behaviour Chord.Backend.Behaviour

        def set_context(context_id, context, version), do: # implementation
        def get_context(context_id), do: # implementation
        def delete_context(context_id), do: # implementation
        # Implement all other callbacks...
      end

  Once implemented, configure the backend in your application:

      config :chord, :backend, MyApp.CustomBackend

  """

  # Context operations

  @doc """
  Sets the context for a given `context_id`.

  ## Parameters
    - `context_id` (any): The identifier for the context.
    - `context` (map): The context data to store.
    - `version` (integer): The version number associated with the context.

  ## Returns
  - `{:ok, %{context_id: any(), context: map(), version: integer(), inserted_at: integer()}}` on success.
  - `{:error, term()}` on failure.
  """
  @callback set_context(context_id :: any(), context :: map(), version :: integer()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Retrieves the context and version for a given `context_id`.

  ## Parameters
    - `context_id` (any): The identifier for the context.

  ## Returns
  - `{:ok, %{context_id: any(), context: map(), version: integer(), inserted_at: integer()}}` on success.
  - `{:error, term()}` on failure.
  """
  @callback get_context(context_id :: any()) :: {:ok, map()} | {:error, term()}

  @doc """
  Deletes the context for a given `context_id`.

  ## Parameters
    - `context_id` (any): The identifier for the context to delete.

  ## Returns
    - `:ok` on success.
    - `{:error, term()}` on failure.
  """
  @callback delete_context(context_id :: any()) :: :ok | {:error, term()}

  # Delta operations

  @doc """
  Sets a delta for a given `context_id` and `version`.

  ## Parameters
    - `context_id` (any): The identifier for the context.
    - `delta` (map): The delta data to store.
    - `version` (integer): The version number associated with the delta.

  ## Returns
  - `{:ok, %{context_id: any(), delta: map(), version: integer(), inserted_at: integer()}}` on success.
  - `{:error, term()}` on failure.
  """
  @callback set_delta(context_id :: any(), delta :: map(), version :: integer()) ::
              {:ok, map()} | {:error, term()}

  @doc """
  Retrieves deltas for a given `context_id` greater than a specified `client_version`.

  ## Parameters
    - `context_id` (any): The identifier for the context.
    - `client_version` (integer): The version from which to retrieve deltas.

  ## Returns
    - `{:ok, list(map())}` on success.
    - `{:error, term()}` if no deltas are found or an error occurs.
  """
  @callback get_deltas(context_id :: any(), client_version :: integer()) ::
              {:ok, list(map())} | {:error, term()}

  @doc """
  Deletes all deltas for a given `context_id`.

  ## Parameters
    - `context_id` (any): The identifier for the context.

  ## Returns
    - `:ok` on success.
    - `{:error, term()}` on failure.
  """
  @callback delete_deltas_for_context(context_id :: any()) :: :ok | {:error, term()}

  @doc """
  Deletes deltas older than a specified time for a given `context_id`.

  ## Parameters
    - `context_id` (any): The identifier for the context.
    - `older_than_time` (integer): The timestamp threshold.

  ## Returns
    - `:ok` on success.
    - `{:error, term()}` on failure.
  """
  @callback delete_deltas_by_time(context_id :: any(), older_than_time :: integer()) ::
              :ok | {:error, term()}

  @doc """
  Deletes deltas exceeding a specified version threshold for a given `context_id`.

  ## Parameters
    - `context_id` (any): The identifier for the context.
    - `version_threshold` (integer): The maximum number of versions to retain.

  ## Returns
    - `:ok` on success.
    - `{:error, term()}` on failure.
  """
  @callback delete_deltas_exceeding_threshold(context_id :: any(), version_threshold :: integer()) ::
              :ok | {:error, term()}

  # Listing operations

  @doc """
  Lists contexts with optional filters and pagination.

  ## Parameters
    - `opts` (Keyword.t): Options for filtering and pagination. Common options include:
      - `:context_id` - Filter by context identifier.
      - `:version` - Filter by version.
      - `:inserted_at` - Filter by insertion timestamp.
      - `:limit` - Maximum number of results to return.
      - `:offset` - Number of results to skip.

  ## Returns
    - `{:ok, list(map())}` on success.
    - `{:error, term()}` on failure.
  """
  @callback list_contexts(opts :: Keyword.t()) :: {:ok, list(map())} | {:error, term()}

  @doc """
  Lists contexts along with their delta counts.

  ## Parameters
    - `opts` (Keyword.t): Options for filtering and pagination.

  ## Returns
    - `{:ok, list(map())}` on success.
    - `{:error, term()}` on failure.
  """
  @callback list_contexts_with_delta_counts(opts :: Keyword.t()) ::
              {:ok, list(map())} | {:error, term()}

  @doc """
  Lists deltas with optional filters and pagination.

  ## Parameters
    - `opts` (Keyword.t): Options for filtering and pagination. Common options include:
      - `:context_id` - Filter by context identifier.
      - `:version` - Filter by version.
      - `:inserted_at` - Filter by insertion timestamp.
      - `:limit` - Maximum number of results to return.
      - `:offset` - Number of results to skip.

  ## Returns
    - `{:ok, list(map())}` on success.
    - `{:error, term()}` on failure.
  """
  @callback list_deltas(opts :: Keyword.t()) :: {:ok, list(map())} | {:error, term()}
end
