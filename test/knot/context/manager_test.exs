defmodule Knot.Context.ManagerTest do
  use ExUnit.Case, async: true
  import TestHelpers
  alias Knot.Context.Manager
  alias Knot.Delta

  setup do
    Application.put_env(:knot, :backend, Knot.Backend.Mock)
    Application.put_env(:knot, :delta_threshold, 100)

    context_id = "group:1"
    old_context = %{name: "Alice", status: "online"}
    new_context = %{name: "Alice", status: "offline", location: "Earth"}
    client_version = 1

    {:ok,
     context_id: context_id,
     old_context: old_context,
     new_context: new_context,
     client_version: client_version}
  end

  describe "Context Management" do
    test "fetches the current context", %{context_id: context_id, old_context: old_context} do
      mock_get_context_expectation(context_id: context_id, context: old_context, version: 1)

      assert Manager.get_context(context_id) == {:ok, {old_context, 1}}
    end

    test "calculates delta and updates context", %{
      context_id: context_id,
      old_context: old_context,
      new_context: new_context
    } do
      delta = Delta.calculate_delta(old_context, new_context)
      mock_get_context_expectation(context_id: context_id, context: old_context, version: 1)
      mock_set_context_expectation(context_id: context_id, context: new_context, version: 2)
      mock_set_delta_expectation(context_id: context_id, delta: delta, version: 2)

      assert Manager.set_context(context_id, new_context) == {:ok, {new_context, delta, 2}}
    end
  end

  describe "Synchronization Logic" do
    test "returns full context if client version is nil", %{
      context_id: context_id,
      old_context: old_context
    } do
      mock_get_context_expectation(context_id: context_id, context: old_context, version: 1)

      assert Manager.sync_context(context_id, nil) == {:full_context, {old_context, 1}}
    end

    test "returns no_change if client version matches", %{
      context_id: context_id,
      old_context: old_context
    } do
      mock_get_context_expectation(context_id: context_id, context: old_context, version: 1)

      assert Manager.sync_context(context_id, 1) == {:no_change, 1}
    end

    test "returns delta for valid client version", %{
      context_id: context_id,
      old_context: old_context,
      new_context: new_context,
      client_version: client_version
    } do
      delta = Delta.calculate_delta(old_context, new_context)
      mock_get_context_expectation(context_id: context_id, context: new_context, version: 2)
      mock_get_deltas_expectation(context_id: context_id, delta: delta, version: client_version)

      assert Manager.sync_context(context_id, client_version) ==
               {:delta, {delta, 2}}
    end

    test "returns full context if no deltas exist", %{
      context_id: context_id,
      old_context: old_context
    } do
      mock_get_context_expectation(context_id: context_id, context: old_context, version: 1)
      mock_get_deltas_expectation(context_id: context_id, delta: [], version: 0)

      assert Manager.sync_context(context_id, 0) == {:full_context, {old_context, 1}}
    end
  end

  describe "Context Deletion" do
    test "deletes context for a given context_id" do
      context_id = "game:1"
      mock_delete_context_expectation(context_id: context_id)

      assert Manager.delete_context(context_id) == :ok
    end
  end
end
