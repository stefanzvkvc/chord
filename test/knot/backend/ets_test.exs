defmodule Knot.Backend.ETSTest do
  use ExUnit.Case
  alias Knot.Backend.ETS

  setup do
    # Ensure the ETS tables are fresh before every test
    :ets.new(:knot_state_table, [:named_table, :set, :public])
    :ets.new(:knot_state_history_table, [:named_table, :bag, :public])
    :ok
  end

  test "get_state for a non-existent context_id" do
    context_id = "group:non_existent"

    assert ETS.get_state(context_id) == {%{}, 0}
  end

  test "set_state stores state correctly" do
    context_id = "group:1"
    state = %{name: "Alice", status: "online"}
    version = 1

    # Store the state and delta
    ETS.set_state(context_id, state, version)

    # Validate the current state and version
    assert ETS.get_state(context_id) == {state, version}
  end

  test "set_delta stores delta correctly" do
    context_id = "group:1"
    delta = %{status: %{action: :modified, old_value: "offline", value: "online"}}
    version = 1

    # Store the state and delta
    ETS.set_delta(context_id, delta, version)

    # Validate the delta in the history table
    history = ETS.get_state_history(context_id, 0)
    assert history == [delta]
  end

  test "updated state overwrites initial state and appends to history" do
    context_id = "group:1"
    initial_state = %{name: "Alice", status: "online"}
    updated_state = %{name: "Alice", status: "offline"}
    initial_delta = %{status: %{action: :added, value: "online"}}
    updated_delta = %{status: %{action: :modified, old_value: "online", value: "offline"}}
    initial_version = 1
    updated_version = 2

    # Store the initial state and delta
    ETS.set_state(context_id, initial_state, initial_version)
    ETS.set_delta(context_id, initial_delta, initial_version)
    assert ETS.get_state(context_id) == {initial_state, initial_version}
    assert ETS.get_state_history(context_id, 0) == [initial_delta]

    # Update the state and append the new delta
    ETS.set_state(context_id, updated_state, updated_version)
    ETS.set_delta(context_id, updated_delta, updated_version)
    assert ETS.get_state(context_id) == {updated_state, updated_version}
    assert ETS.get_state_history(context_id, 0) == [initial_delta, updated_delta]
  end

  test "get_state_history retrieves only newer versions" do
    initial_delta = %{step: %{action: :added, value: 1}}
    updated_delta_v1 = %{step: %{action: :modified, old_value: 1, value: 2}}
    updated_delta_v2 = %{step: %{action: :modified, old_value: 2, value: 3}}
    ETS.set_delta("group:1", initial_delta, 1)
    ETS.set_delta("group:1", updated_delta_v1, 2)
    ETS.set_delta("group:1", updated_delta_v2, 3)

    assert ETS.get_state_history("group:1", 1) == [updated_delta_v1, updated_delta_v2]
    assert ETS.get_state_history("group:1", 2) == [updated_delta_v2]
    assert ETS.get_state_history("group:1", 3) == []
  end

  test "empty list when no history exists" do
    context_id = "group:non_existent"
    client_version = 1

    assert ETS.get_state_history(context_id, client_version) == []
  end
end
