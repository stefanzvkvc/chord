defmodule Chord.Context.ManagerTest do
  use ExUnit.Case, async: true
  import Chord.Support.MocksHelpers.Backend
  alias Chord.Context.Manager
  alias Chord.Delta

  setup do
    Application.put_env(:chord, :backend, Chord.Support.Mocks.Backend)
    Application.put_env(:chord, :delta_threshold, 100)

    context_id = "group:1"
    old_context = %{name: "Alice", status: "online"}
    new_context = %{name: "Alice", status: "offline", location: "Earth"}
    partial_update = %{status: "offline"}
    client_version = 1
    current_time = 1_673_253_120

    {:ok,
     context_id: context_id,
     old_context: old_context,
     new_context: new_context,
     partial_update: partial_update,
     client_version: client_version,
     current_time: current_time}
  end

  describe "Context Management" do
    test "gets the current context", %{
      context_id: context_id,
      old_context: old_context,
      current_time: current_time
    } do
      mock_get_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      expected_result =
        {:ok,
         %{context_id: context_id, context: old_context, version: 1, inserted_at: current_time}}

      assert Manager.get_context(context_id) == expected_result
    end

    test "calculates delta and updates context", %{
      context_id: context_id,
      old_context: old_context,
      new_context: new_context,
      current_time: current_time
    } do
      delta = Delta.calculate_delta(old_context, new_context)

      mock_get_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      mock_set_context(
        context_id: context_id,
        context: new_context,
        version: 2,
        inserted_at: current_time
      )

      mock_set_delta(context_id: context_id, delta: delta, version: 2, inserted_at: current_time)

      expected_result = {
        :ok,
        %{
          context: %{
            context_id: context_id,
            context: new_context,
            version: 2,
            inserted_at: current_time
          },
          delta: %{context_id: context_id, delta: delta, version: 2, inserted_at: current_time}
        }
      }

      assert Manager.set_context(context_id, new_context) == expected_result
    end

    test "partially updates the context", %{
      context_id: context_id,
      old_context: old_context,
      partial_update: partial_update,
      current_time: current_time
    } do
      updated_context = Chord.Utils.Context.MapTransform.deep_update(old_context, partial_update)
      delta = Delta.calculate_delta(old_context, updated_context)

      mock_get_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      mock_set_context(
        context_id: context_id,
        context: updated_context,
        version: 2,
        inserted_at: current_time
      )

      mock_set_delta(context_id: context_id, delta: delta, version: 2, inserted_at: current_time)

      expected_result = {
        :ok,
        %{
          context: %{
            context_id: context_id,
            context: updated_context,
            version: 2,
            inserted_at: current_time
          },
          delta: %{context_id: context_id, delta: delta, version: 2, inserted_at: current_time}
        }
      }

      assert Manager.update_context(context_id, partial_update) == expected_result
    end

    test "skipping update when there is no change", %{
      context_id: context_id,
      old_context: old_context,
      current_time: current_time
    } do
      mock_get_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      expected_result = {:ok, %{context: old_context, delta: %{}}}
      assert Manager.set_context(context_id, old_context) == expected_result
    end
  end

  describe "Synchronization Logic" do
    test "returns full context if client version is nil", %{
      context_id: context_id,
      old_context: old_context,
      current_time: current_time
    } do
      mock_get_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      expected_result =
        {:full_context,
         %{context_id: context_id, context: old_context, version: 1, inserted_at: current_time}}

      assert Manager.sync_context(context_id, nil) == expected_result
    end

    test "returns no_change if client version matches", %{
      context_id: context_id,
      old_context: old_context,
      current_time: current_time
    } do
      mock_get_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      expected_result = {:no_change, 1}
      assert Manager.sync_context(context_id, 1) == expected_result
    end

    test "returns delta for valid client version", %{
      context_id: context_id,
      old_context: old_context,
      new_context: new_context,
      client_version: client_version,
      current_time: current_time
    } do
      delta = Delta.calculate_delta(old_context, new_context)

      mock_get_context(
        context_id: context_id,
        context: new_context,
        version: 2,
        inserted_at: current_time
      )

      mock_get_deltas(context_id: context_id, delta: delta, version: 1, inserted_at: current_time)

      expected_result =
        {:delta, %{context_id: context_id, delta: delta, version: 2, inserted_at: current_time}}

      assert Manager.sync_context(context_id, client_version) == expected_result
    end

    test "returns full context if no deltas exist", %{
      context_id: context_id,
      old_context: old_context,
      current_time: current_time
    } do
      mock_get_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      mock_get_deltas(context_id: context_id, version: 0, error: {:error, :not_found})

      expected_result =
        {:full_context,
         %{context_id: context_id, context: old_context, version: 1, inserted_at: current_time}}

      assert Manager.sync_context(context_id, 0) == expected_result
    end
  end

  describe "Context Deletion" do
    test "deletes context for a given context_id" do
      context_id = "game:1"
      mock_delete_context(context_id: context_id)
      mock_delete_deltas_for_context(context_id: context_id)

      assert Manager.delete_context(context_id) == :ok
    end
  end

  describe "Export Context" do
    test "exports the current context", %{
      context_id: context_id,
      old_context: old_context,
      current_time: current_time
    } do
      mock_get_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      Application.put_env(:chord, :export_callback, fn context ->
        assert context == %{
                 context_id: context_id,
                 context: old_context,
                 version: 1,
                 inserted_at: current_time
               }

        :ok
      end)

      assert Manager.export_context(context_id) == :ok
    end

    test "handles missing context gracefully during export", %{context_id: context_id} do
      mock_get_context(context_id: context_id, error: {:error, :not_found})
      assert Manager.export_context(context_id) == {:error, :not_found}
    end

    test "handles missing export callback gracefully", %{
      context_id: context_id,
      old_context: old_context
    } do
      Application.delete_env(:chord, :export_callback)
      mock_get_context(context_id: context_id, context: old_context, version: 1)
      assert Manager.export_context(context_id) == {:error, :no_export_callback}
    end
  end

  describe "Restore Context" do
    test "successfully restores a context from external storage", %{
      context_id: context_id,
      old_context: old_context,
      current_time: current_time
    } do
      Application.put_env(:chord, :context_external_provider, fn context_id ->
        {:ok,
         %{
           context_id: context_id,
           context: old_context,
           version: 1,
           inserted_at: current_time
         }}
      end)

      mock_set_context(
        context_id: context_id,
        context: old_context,
        version: 1,
        inserted_at: current_time
      )

      expected_result =
        {:ok,
         %{context_id: context_id, context: old_context, version: 1, inserted_at: current_time}}

      assert Manager.restore_context(context_id) == expected_result
    end

    test "handles missing context in external storage", %{context_id: context_id} do
      Application.put_env(:chord, :context_external_provider, fn context_id ->
        {:error, :not_found}
      end)

      expected_result = {:error, :not_found}
      assert Manager.restore_context(context_id) == expected_result
    end

    test "handles missing context external provider callback gracefully", %{
      context_id: context_id,
      old_context: old_context
    } do
      Application.delete_env(:chord, :context_external_provider)
      expected_result = {:error, :no_context_external_provider}
      assert Manager.restore_context(context_id) == expected_result
    end
  end
end
