defmodule Knot.DeltaTest do
  use ExUnit.Case

  alias Knot.Delta

  describe "calculate_delta/2" do
    test "calculates added keys" do
      current_state = %{name: "Alice"}
      new_state = %{name: "Alice", age: 30}

      delta = Delta.calculate_delta(current_state, new_state)
      assert delta == %{age: %{action: :added, value: 30}}
    end

    test "calculates removed keys" do
      current_state = %{name: "Alice", age: 30}
      new_state = %{name: "Alice"}

      delta = Delta.calculate_delta(current_state, new_state)
      assert delta == %{age: %{action: :removed}}
    end

    test "calculates modified keys" do
      current_state = %{name: "Alice", status: "online"}
      new_state = %{name: "Alice", status: "offline"}

      delta = Delta.calculate_delta(current_state, new_state)
      assert delta == %{status: %{action: :modified, old_value: "online", value: "offline"}}
    end
  end

  describe "merge_deltas/1" do
    test "merges added and modified keys" do
      delta1 = %{name: %{action: :added, value: "Alice"}}
      delta2 = %{status: %{action: :added, value: "online"}}

      merged = Delta.merge_deltas([delta1, delta2])

      assert merged == %{
               name: %{action: :added, value: "Alice"},
               status: %{action: :added, value: "online"}
             }
    end

    test "handles removed keys" do
      delta1 = %{name: %{action: :added, value: "Alice"}}
      delta2 = %{name: %{action: :removed}}

      merged = Delta.merge_deltas([delta1, delta2])
      assert merged == %{name: %{action: :removed}}
    end
  end

  describe "format_delta/2" do
    test "formats delta" do
      delta = %{name: %{action: :modified, old_value: "Alice", value: "Bob"}}
      formatted = Delta.format_delta(delta, "group:1")

      assert formatted == [
               %{
                 context: "group:1",
                 key: :name,
                 action: :modified,
                 old_value: "Alice",
                 value: "Bob"
               }
             ]
    end
  end
end
