defmodule Chord.DeltaTest do
  use ExUnit.Case

  alias Chord.Delta

  describe "calculate_delta/2" do
    test "calculates added keys" do
      current_context = %{name: "Alice"}
      new_context = %{name: "Alice", age: 30}
      expected_delta = %{age: %{action: :added, value: 30}}

      assert Delta.calculate_delta(current_context, new_context) == expected_delta
    end

    test "calculates removed keys" do
      current_context = %{name: "Alice", age: 30}
      new_context = %{name: "Alice"}
      expected_delta = %{age: %{action: :removed, old_value: 30}}

      assert Delta.calculate_delta(current_context, new_context) == expected_delta
    end

    test "calculates modified keys" do
      current_context = %{name: "Alice", status: "online"}
      new_context = %{name: "Alice", status: "offline"}
      expected_delta = %{status: %{action: :modified, old_value: "online", value: "offline"}}

      assert Delta.calculate_delta(current_context, new_context) == expected_delta
    end

    test "handles nil values correctly" do
      current_context = %{name: "Alice", status: nil}
      new_context = %{name: "Alice", status: "online"}
      expected_delta = %{status: %{action: :modified, old_value: nil, value: "online"}}

      assert Delta.calculate_delta(current_context, new_context) == expected_delta
    end

    test "handles nested maps" do
      current_context = %{
        users: %{"Alice" => %{status: "offline", age: 30}, "Bob" => %{status: "online", age: 30}}
      }

      new_context = %{
        users: %{"Alice" => %{status: "online", age: 30}, "Bob" => %{status: "online", age: 30}}
      }

      expected_delta = %{
        users: %{
          "Alice" => %{status: %{action: :modified, old_value: "offline", value: "online"}}
        }
      }

      assert Delta.calculate_delta(current_context, new_context) == expected_delta
    end
  end

  describe "merge_deltas/1" do
    test "merges added and modified keys" do
      delta1 = %{name: %{action: :added, value: "Alice"}}
      delta2 = %{status: %{action: :added, value: "online"}}

      expected_delta = %{
        name: %{action: :added, value: "Alice"},
        status: %{action: :added, value: "online"}
      }

      assert Delta.merge_deltas([delta1, delta2]) == expected_delta
    end

    test "handles removed keys" do
      delta1 = %{name: %{action: :added, value: "Alice"}}
      delta2 = %{name: %{action: :removed, old_value: "Alice"}}
      expected_delta = %{name: %{action: :removed, old_value: "Alice"}}

      assert Delta.merge_deltas([delta1, delta2]) == expected_delta
    end

    test "handles nested deltas" do
      delta1 = %{
        users: %{
          "Alice" => %{status: %{action: :modified, old_value: "offline", value: "online"}}
        }
      }

      delta2 = %{
        users: %{
          "Alice" => %{avatar: %{action: :added, value: "avatar_url"}}
        }
      }

      delta3 = %{
        users: %{
          "Alice" => %{about: %{action: :modified, old_value: nil, value: "Alice In Wonderland"}}
        }
      }

      delta4 = %{
        users: %{
          "Alice" => %{avatar: %{action: :removed, old_value: "avatar_url"}}
        }
      }

      expected_delta = %{
        users: %{
          "Alice" => %{
            status: %{value: "online", action: :modified, old_value: "offline"},
            avatar: %{action: :removed, old_value: "avatar_url"},
            about: %{value: "Alice In Wonderland", action: :modified, old_value: nil}
          }
        }
      }

      assert Delta.merge_deltas([delta1, delta2, delta3, delta4]) == expected_delta
    end
  end

  describe "format_delta/2" do
    test "formats delta" do
      delta = %{name: %{action: :modified, old_value: "Alice", value: "Bob"}}
      formatted = Delta.format_delta(delta, %{context_id: "group:1", version: 1})

      assert formatted == %{
               version: 1,
               changes: [
                 %{
                   value: "Bob",
                   key: :name,
                   action: :modified,
                   context_id: "group:1",
                   old_value: "Alice"
                 }
               ]
             }
    end

    test "handles nested delta" do
      delta = %{
        status: %{action: :added, value: "online"},
        metadata: %{
          language: %{action: :added, value: "en-US"},
          theme: %{action: :modified, old_value: "light", value: "dark"}
        }
      }

      formatted = Delta.format_delta(delta, %{context_id: "user:369", version: 2})

      assert formatted == %{
               changes: [
                 %{action: :added, context_id: "user:369", key: :status, value: "online"},
                 %{
                   action: :added,
                   context_id: "user:369",
                   key: [:metadata, :language],
                   value: "en-US"
                 },
                 %{
                   action: :modified,
                   context_id: "user:369",
                   key: [:metadata, :theme],
                   old_value: "light",
                   value: "dark"
                 }
               ],
               version: 2
             }
    end
  end
end
