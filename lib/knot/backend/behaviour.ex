defmodule Knot.Backend.Behaviour do
  @moduledoc """
  Defines the behavior for backends used by Knot.
  """

  # Context operations
  @callback set_context(context_id :: any(), state :: map(), version :: integer()) ::
              {:ok, {map(), integer()}} | {:error, term()}
  @callback get_context(context_id :: any()) :: {:ok, {map(), integer()}} | {:error, term()}
  @callback delete_context(context_id :: any()) :: :ok | {:error, term()}

  # Delta operations
  @callback set_delta(context_id :: any(), delta :: map(), version :: integer()) ::
              {:ok, {map(), integer()}} | {:error, term()}
  @callback get_deltas(context_id :: any(), client_version :: integer()) ::
              {:ok, list(map())} | {:error, term()}
  @callback delete_deltas_for_context(context_id :: any()) :: :ok | {:error, term()}
  @callback delete_deltas_by_time(context_id :: any(), older_than_time :: integer()) ::
              :ok | {:error, term()}
  @callback delete_deltas_exceeding_threshold(context_id :: any(), version_threshold :: integer()) ::
              :ok | {:error, term()}

  # Listing operations
  @callback list_contexts(opts :: Keyword.t()) :: {:ok, list(map())} | {:error, term()}
  @callback list_contexts_with_delta_counts(opts :: Keyword.t()) ::
              {:ok, list(map())} | {:error, term()}
  @callback list_deltas(opts :: Keyword.t()) :: {:ok, list(map())} | {:error, term()}
end
