defmodule Knot.StateManagerTest do
  use ExUnit.Case
  import Knot.StateManager

  setup do
    # Reset the backend (e.g., clear ETS tables) before each test
    :ets.new(:knot_state_table, [:named_table, :set, :public])
    :ets.new(:knot_state_history_table, [:named_table, :bag, :public])
    :ok
  end

  test "fetches initial state for a given context" do
    context_id = "group:1"
    state = %{}

    assert fetch_state(context_id) == {state, 0}
  end

  test "syncs new state and calculates delta" do
    context_id = "group:1"
    old_state = %{name: "Alice", status: "online"}
    new_state = %{name: "Alice", status: "offline", location: "Earth"}

    {:ok, old_version} = sync_state(context_id, old_state)
    {:ok, new_version} = sync_state(context_id, new_state)

    assert new_version > old_version
    assert fetch_state(context_id) == {new_state, new_version}
  end

  test "delivers full state on reconnect when no version is provided" do
    context_id = "group:1"
    state = %{name: "Alice", status: "online"}

    {:ok, new_version} = sync_state(context_id, state)
    {:full_state, full_state, ^new_version} = handle_reconnect(context_id, nil)

    assert full_state == state
  end

  test "delivers delta on reconnect when client version matches history" do
    context_id = "group:1"
    old_state = %{name: "Alice", status: "online"}
    new_state = %{name: "Alice", status: "offline", location: "Earth"}

    {:ok, old_version} = sync_state(context_id, old_state)
    {:ok, new_version} = sync_state(context_id, new_state)

    {:delta, delta, ^new_version} = handle_reconnect(context_id, old_version)

    assert delta == %{
             "status" => %{action: :modified, old_value: "online", value: "offline"},
             "location" => %{action: :added, value: "Earth"}
           }
  end

  test "delivers full state on reconnect when client's version is too old" do
    # Set the delta threshold to a smaller value for this test
    Application.put_env(:knot, :delta_threshold, 2)
    context_id = "group:1"
    state_v1 = %{name: "Alice", status: "online"}
    state_v2 = %{name: "Alice", status: "offline"}
    state_v3 = %{name: "Alice", status: "offline", location: "Earth"}

    {:ok, _} = sync_state(context_id, state_v1)
    {:ok, _} = sync_state(context_id, state_v2)
    {:ok, new_version} = sync_state(context_id, state_v3)

    # Simulate client reconnecting with an outdated version
    {:full_state, full_state, ^new_version} = handle_reconnect(context_id, 0)

    assert full_state == state_v3
  end

  test "delivers full state on reconnect when no history matches client version" do
    context_id = "group:1"
    state_v1 = %{name: "Alice", status: "online"}
    state_v2 = %{name: "Alice", status: "offline"}

    {:ok, _} = sync_state(context_id, state_v1)
    {:ok, new_version} = sync_state(context_id, state_v2)

    # Simulate clearing history
    :ets.delete_all_objects(:knot_state_history_table)

    {:full_state, full_state, ^new_version} = handle_reconnect(context_id, 1)

    assert full_state == state_v2
  end
end
