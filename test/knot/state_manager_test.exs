defmodule Knot.StateManagerTest do
  use ExUnit.Case, async: true
  import Mox
  alias Knot.StateManager
  alias Knot.Backend.Mock
  alias Knot.Delta

  setup :verify_on_exit!

  setup do
    Application.put_env(:knot, :backend, Knot.Backend.Mock)
    Application.put_env(:knot, :delta_threshold, 100)

    context_id = "group:1"
    device_id = "device:1"
    old_state = %{name: "Alice", status: "online"}
    new_state = %{name: "Alice", status: "offline", location: "Earth"}
    client_version = 1

    {:ok,
     context_id: context_id,
     device_id: device_id,
     old_state: old_state,
     new_state: new_state,
     client_version: client_version}
  end

  test "get_state fetches the current state", %{context_id: context_id, old_state: old_state} do
    Mock
    |> expect(:get_state, fn ^context_id -> {old_state, 1} end)

    assert StateManager.get_state(context_id) == {old_state, 1}
  end

  test "set_state calculates delta and updates state", %{
    context_id: context_id,
    device_id: device_id,
    old_state: old_state,
    new_state: new_state
  } do
    delta = Delta.calculate_delta(old_state, new_state)

    Mock
    |> expect(:get_state, fn ^context_id -> {old_state, 1} end)
    |> expect(:set_state, fn ^context_id, ^new_state, 2 -> :ok end)
    |> expect(:set_delta, fn ^context_id, ^device_id, ^delta, 2 -> :ok end)

    assert StateManager.set_state(context_id, device_id, new_state) == {:ok, 2, new_state, delta}
  end

  test "sync_state returns full state if client version is nil", %{
    context_id: context_id,
    device_id: device_id,
    old_state: old_state
  } do
    Mock
    |> expect(:get_state, fn ^context_id -> {old_state, 1} end)
    |> expect(:delete_deltas_by_version, fn ^context_id, ^device_id, -99 -> :ok end)

    assert StateManager.sync_state(context_id, device_id, nil) ==
             {:full_state, old_state, 1}
  end

  test "sync_state returns no_change if client version matches", %{
    context_id: context_id,
    device_id: device_id,
    old_state: old_state
  } do
    Mock
    |> expect(:get_state, fn ^context_id -> {old_state, 1} end)

    assert StateManager.sync_state(context_id, device_id, 1) == {:no_change, 1}
  end

  test "sync_state returns delta for valid client version", %{
    context_id: context_id,
    device_id: device_id,
    old_state: old_state,
    new_state: new_state,
    client_version: client_version
  } do
    delta = Delta.calculate_delta(old_state, new_state)

    Mock
    |> expect(:get_state, fn ^context_id -> {new_state, 2} end)
    |> expect(:get_delta, fn ^context_id, ^device_id, ^client_version -> [delta] end)
    |> expect(:delete_deltas_by_version, fn ^context_id, ^device_id, ^client_version -> :ok end)

    assert StateManager.sync_state(context_id, device_id, client_version) ==
             {:delta, delta, 2}
  end

  test "sync_state returns full state if no deltas exist", %{
    context_id: context_id,
    device_id: device_id,
    old_state: old_state
  } do
    Mock
    |> expect(:get_state, fn ^context_id -> {old_state, 1} end)
    |> expect(:get_delta, fn ^context_id, ^device_id, 0 -> [] end)

    assert StateManager.sync_state(context_id, device_id, 0) == {:full_state, old_state, 1}
  end

  test "deletes state for a given context_id" do
    context_id = "game:1"

    Mock
    |> expect(:delete_state, fn ^context_id -> :ok end)

    assert StateManager.delete_state(context_id) == :ok
  end

  test "deletes deltas for a specific device" do
    context_id = "game:1"
    device_id = "deviceA"

    Mock
    |> expect(:delete_deltas_by_device, fn ^context_id, ^device_id -> :ok end)

    assert StateManager.delete_deltas_by_device(context_id, device_id) == :ok
  end
end
