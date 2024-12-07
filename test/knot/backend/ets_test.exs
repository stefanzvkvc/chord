defmodule Knot.Backend.ETSTest do
  use ExUnit.Case
  alias Knot.Backend.ETS

  setup do
    # Ensure the ETS table is fresh before every test
    :ets.new(:knot_state_table, [:named_table, :set, :public])
    :ets.new(:knot_state_history_table, [:named_table, :bag, :public])
    :ok
  end

  test "get state for a non-existent context_id" do
    context_id = "group:non_existent"

    assert ETS.get_state(context_id) == {%{}, 0}
  end

  test "set and get state for a context_id" do
    context_id = "group:1"
    state = %{name: "Alice", status: "online"}
    version = 1

    ETS.set_state(context_id, state, version)
    assert ETS.get_state(context_id) == {state, version}
  end

  test "updated state overwrites initial state" do
    context_id = "group:1"
    initial_state = %{name: "Alice", status: "online"}
    updated_state = %{name: "Alice", status: "offline"}
    initial_version = 1
    updated_version = 2

    # Set initial state
    ETS.set_state(context_id, initial_state, initial_version)
    assert ETS.get_state(context_id) == {initial_state, initial_version}

    # Update state
    ETS.set_state(context_id, updated_state, updated_version)
    assert ETS.get_state(context_id) == {updated_state, updated_version}
  end

  test "empty list when no history exists" do
    context_id = "group:1"
    client_version = 1

    assert ETS.get_state_history(context_id, client_version) == []
  end

  test "get_state_history retrieves only newer versions" do
    ETS.set_state("group:1", %{step: 1}, 1)
    ETS.set_state("group:1", %{step: 2}, 2)
    ETS.set_state("group:1", %{step: 3}, 3)

    assert ETS.get_state_history("group:1", 1) == [%{step: 2}, %{step: 3}]
    assert ETS.get_state_history("group:1", 2) == [%{step: 3}]
    assert ETS.get_state_history("group:1", 3) == []
  end
end
