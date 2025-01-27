defmodule Chord.Utils.Context.MapTransform do
  @moduledoc """
  Utilities for manipulating nested maps, including deep merging.
  """

  @doc """
  Updates a deeply nested map using another map of updates.

  ## Parameters
    - `original` (map): The original map to be updated.
    - `updates` (map): A map containing the updates to be applied.

  ## Notes
    - Preserves the structure of the original map while applying the updates.
    - Creates missing keys in the original map if they are present in the updates.

  ## Examples
      iex> alias Chord.Utils.Context.MapTransform
      iex> original = %{users: %{user_a: %{name: "Alice", age: 30}, user_b: %{name: "Bob", age: 25}}}
      iex> updates = %{users: %{user_b: %{age: 26}}}
      iex> MapTransform.deep_update(original, updates)
      %{users: %{user_a: %{name: "Alice", age: 30}, user_b: %{name: "Bob", age: 26}}}

      iex> original = %{}
      iex> updates = %{users: %{user_a: %{profile: %{name: "Alice"}}}}
      iex> MapTransform.deep_update(original, updates)
      %{users: %{user_a: %{profile: %{name: "Alice"}}}}
  """
  def deep_update(original, updates) when is_map(original) and is_map(updates) do
    do_deep_update(original, updates)
  end

  defp do_deep_update(original, updates) do
    Map.merge(original, updates, fn _key, original_value, update_value ->
      if is_map(original_value) and is_map(update_value) do
        do_deep_update(original_value, update_value)
      else
        update_value
      end
    end)
  end
end
