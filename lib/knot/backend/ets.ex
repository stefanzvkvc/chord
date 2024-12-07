defmodule Knot.Backend.ETS do
  @moduledoc """
  ETS-based backend with versioning support.
  """
  @behaviour Knot.Backend.Behaviour
  @state_table :knot_state_table
  @history_table :knot_state_history_table

  # Fetch the current state and version for a given context_id
  @impl true
  def get_state(context_id) do
    ensure_table_exists()

    case :ets.lookup(@state_table, context_id) do
      [{^context_id, state, version}] -> {state, version}
      # Default state and version
      [] -> {%{}, 0}
    end
  end

  # Set the state and version for a given context_id
  @impl true
  def set_state(context_id, state, version) do
    ensure_table_exists()

    # Store the current state and version in the main table
    :ets.insert(@state_table, {context_id, state, version})

    # Optionally store the history for deltas
    :ets.insert(@history_table, {context_id, version, state})

    :ok
  end

  # Retrieve the state history for calculating deltas
  @impl true
  def get_state_history(context_id, client_version) do
    ensure_table_exists()

    # Fetch all states since the client's version
    :ets.match_object(@history_table, {context_id, :"$1", :"$2"})
    |> Enum.filter(fn {_, version, _} -> version > client_version end)
    |> Enum.map(fn {_, _, state} -> state end)
  end

    # Ensure the ETS table exists
    defp ensure_table_exists do
      unless :ets.info(@state_table) do
        :ets.new(@state_table, [:named_table, :set, :public])
      end

      unless :ets.info(@history_table) do
        :ets.new(@history_table, [:named_table, :bag, :public])
      end
    end
end
