defmodule Knot.Context.Manager do
  @moduledoc """
  Orchestrates context synchronization, delta calculation.
  """
  alias Knot.Delta
  @default_backend Knot.Backend.ETS
  @default_delta_threshold 100

  @doc """
  Retrieves the current context and version for a given identifier.

  ## Parameters
    - `context_id` (any): The ID of the context whose state is to be retrieved.

  ## Returns
    - `{:ok, {context, version}}`: The current context and version for the identifier.
    - `{:error, reason}`: If the context retrieval fails.

  ## Example
      iex> Knot.Context.Manager.get_context("game:1")
      {:ok, %{score: 100}, 1}
  """
  @spec get_context(context_id :: any()) :: {:ok, {map(), integer()}} | {:error, term()}
  def get_context(context_id) do
    backend().get_context(context_id)
  end

  @doc """
  Updates the global context for a given identifier and calculates deltas.

  This function updates the context and stores deltas, enabling efficient synchronization.

  ## Parameters
    - `context_id` (any): The ID of the context to update.
    - `new_context` (map): The new context to set.

  ## Returns
    - `{:ok, {new_context, delta, new_version}}`: On success, returns the updated version, context, and calculated delta.

  ## Example
      iex> Knot.Context.Manager.set_context("game:1", %{score: 200})
      {:ok, {%{score: 200}, %{score: %{action: :modified, old_value: 100, value: 200}}, 2}}
  """
  @spec set_context(context_id :: any(), new_context :: map()) :: {:ok, {map(), map(), integer()}}
  def set_context(context_id, new_context) do
    {:ok, {old_context, old_version}} = get_context(context_id)
    new_version = old_version + 1
    delta = Delta.calculate_delta(old_context, new_context)

    # TODO: introduce explicit error handling
    {:ok, {_new_conext, _new_version}} =
      backend().set_context(context_id, new_context, new_version)

    {:ok, _delta} = backend().set_delta(context_id, delta, new_version)
    {:ok, {new_context, delta, new_version}}
  end

  @doc """
  Synchronizes the context for a specific identifier.

  This function determines whether the client needs the full context, deltas, or no updates based on its current version.

  ## Parameters
    - `context_id` (any): The ID of the context to synchronize.
    - `client_version` (integer | nil): The version known by the client. If `nil`, the full context is sent.

  ## Returns
    - `{:full_context, context, version}`: If the client's version is too outdated, returns the full context.
    - `{:delta, delta, version}`: If the client is behind but within delta range, returns the calculated delta.
    - `{:no_change, version}`: If the client is up-to-date, indicates no changes.

  ## Example
      iex> Knot.Context.Manager.sync_context("game:1", nil)
      {:full_context, %{score: 200}, 2}

      iex> Knot.Context.Manager.sync_context("game:1", 1)
      {:delta, %{score: %{action: :modified, old_value: 100, value: 200}}, 2}

      iex> Knot.Context.Manager.sync_context("game:1", 2)
      {:no_change, 2}
  """
  @spec sync_context(context_id :: any(), client_version :: integer() | nil) ::
          {:full_context, map(), integer()} | {:delta, map(), integer()} | {:no_change, integer()}
  def sync_context(context_id, client_version) do
    {:ok, {current_context, current_version}} = get_context(context_id)

    case determine_sync_action(client_version, current_version) do
      :full_context ->
        {:full_context, {current_context, current_version}}

      :no_change ->
        {:no_change, current_version}

      :deltas ->
        {:ok, delta_history} = backend().get_deltas(context_id, client_version)

        if delta_history == [] do
          {:full_context, {current_context, current_version}}
        else
          delta = Delta.merge_deltas(delta_history)
          {:delta, {delta, current_version}}
        end
    end
  end

  @doc """
  Deletes the context and associated deltas for a given identifier.

  ## Parameters
    - `context_id` (any): The ID of the context to delete.

  ## Returns
    - `:ok` if the deletion succeeds.

  ## Example
      iex> Knot.Context.Manager.delete_context("game:1")
      :ok
  """
  @spec delete_context(context_id :: any()) :: :ok | {:error, term()}
  def delete_context(context_id) do
    backend().delete_context(context_id)
  end

  @doc false
  defp determine_sync_action(client_version, current_version) do
    cond do
      client_version == nil ->
        :full_context

      client_version < current_version - delta_threshold() ->
        :full_context

      client_version >= current_version ->
        :no_change

      true ->
        :deltas
    end
  end

  @doc false
  defp backend() do
    Application.get_env(:knot, :backend, @default_backend)
  end

  @doc false
  defp delta_threshold() do
    Application.get_env(:knot, :delta_threshold, @default_delta_threshold)
  end
end
