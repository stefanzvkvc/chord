defmodule Knot.Backend.ETSTest do
  use ExUnit.Case
  alias Knot.Backend.ETS

  setup do
    # Ensure fresh ETS tables before each test
    :ets.new(:knot_state_table, [:named_table, :set, :public])
    :ets.new(:knot_state_history_table, [:named_table, :set, :public])
    :ok
  end

  describe "State operations" do
    test "set_state and get_state for a context" do
      context_id = "game:1"
      state = %{score: 100}
      version = 1

      ETS.set_state(context_id, state, version)

      assert ETS.get_state(context_id) == {state, version}
    end

    test "delete_state removes state and related deltas" do
      context_id = "game:2"
      state = %{score: 50}
      version = 1
      device_id = "deviceA"
      delta = %{score: %{action: :added, value: 50}}

      ETS.set_state(context_id, state, version)
      ETS.set_delta(context_id, device_id, delta, version)

      ETS.delete_state(context_id)

      assert ETS.get_state(context_id) == {%{}, 0}
      assert ETS.get_delta(context_id, device_id, 0) == []
    end
  end

  describe "Delta operations" do
    test "set_delta and get_delta for a device" do
      context_id = "game:1"
      device_id = "deviceA"
      old_version = 1
      new_version = 2
      old_delta = %{score: %{action: :added, value: 100}}
      new_delta = %{score: %{action: :modified, old_value: 100, value: 150}}

      ETS.set_delta(context_id, device_id, old_delta, old_version)
      ETS.set_delta(context_id, device_id, new_delta, new_version)

      assert ETS.get_delta(context_id, device_id, old_version) == [new_delta]
      assert ETS.get_delta(context_id, device_id, new_version) == []
    end

    test "delete_deltas_by_device removes deltas for specific device" do
      context_id = "game:1"
      device_id = "deviceA"
      version = 1
      delta = %{score: %{action: :added, value: 100}}

      ETS.set_delta(context_id, device_id, delta, version)
      ETS.delete_deltas_by_device(context_id, device_id)

      assert ETS.get_delta(context_id, device_id, 0) == []
    end

    test "delete_deltas_by_version removes deltas below version threshold" do
      context_id = "game:1"
      device_id = "deviceA"
      version_threshold = 5

      Enum.each(1..10, fn version ->
        delta = %{score: %{action: :added, value: version}}
        ETS.set_delta(context_id, device_id, delta, version)
      end)

      ETS.delete_deltas_by_version(context_id, device_id, version_threshold)

      remaining_deltas = ETS.get_delta(context_id, device_id, 0)
      assert Enum.all?(remaining_deltas, fn %{score: %{value: value}} -> value >= version_threshold end)
    end

    test "delete_deltas_by_time removes deltas older than timestamp" do
      context_id = "game:1"
      device_id = "deviceA"
      current_time = :os.system_time(:second)

      Enum.each(1..10, fn version ->
        delta = %{score: %{action: :added, value: version}}
        timestamp = current_time - version
        :ets.insert(:knot_state_history_table, {{context_id, device_id, version}, delta, timestamp})
      end)

      ETS.delete_deltas_by_time(context_id, device_id, current_time - 5)

      remaining_deltas = ETS.get_delta(context_id, device_id, 0)
      assert Enum.count(remaining_deltas) == 5
    end
  end

  describe "Listing operations" do
    test "list_states returns all states with filters" do
      Enum.each(1..3, fn version ->
        context_id = "game:#{version}"
        state = %{score: version * 10}
        ETS.set_state(context_id, state, version)
      end)

      states = ETS.list_states(limit: 2)
      assert length(states) == 2
    end

    test "list_devices returns all devices with filters" do
      Enum.each(1..3, fn version ->
        context_id = "game:1"
        device_id = "device:#{version}"
        delta = %{score: %{action: :added, value: version}}
        ETS.set_delta(context_id, device_id, delta, version)
      end)

      devices = ETS.list_devices(limit: 2)
      assert length(devices) == 2
    end
  end

  describe "Context activity" do
    test "get_last_activity_timestamp for a context" do
      context_id = "game:1"
      state = %{score: 100}
      version = 1

      ETS.set_state(context_id, state, version)

      timestamp = ETS.get_last_activity_timestamp(context_id)
      assert is_integer(timestamp)
    end
  end
end
