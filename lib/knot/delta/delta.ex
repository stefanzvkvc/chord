defmodule Knot.Delta do
  @moduledoc """
  Provides utilities for calculating and formatting state deltas.
  """

  @default_formatter Knot.Delta.Formatter.Default

  @spec calculate_delta(current_state :: map(), new_state :: map()) :: map()
  def calculate_delta(current_state, new_state) do
    current_state = Map.new(current_state, fn {k, v} -> {k, v} end)
    new_state = Map.new(new_state, fn {k, v} -> {k, v} end)

    # Detect added and modified keys
    added_or_modified =
      Enum.reduce(new_state, %{}, fn {key, new_value}, acc ->
        case Map.get(current_state, key) do
          nil ->
            Map.put(acc, key, %{action: :added, value: new_value})

          old_value when old_value != new_value ->
            Map.put(acc, key, %{action: :modified, old_value: old_value, value: new_value})

          _ ->
            acc
        end
      end)

    # Detect removed keys
    removed =
      Enum.reduce(current_state, %{}, fn {key, _value}, acc ->
        if Map.has_key?(new_state, key) do
          acc
        else
          Map.put(acc, key, %{action: :removed})
        end
      end)

    # Combine results
    Map.merge(added_or_modified, removed)
  end

  @spec merge_deltas(delta_list :: list(map())) :: map()
  def merge_deltas(delta_list) do
    Enum.reduce(delta_list, %{}, fn delta, acc ->
      Map.merge(acc, delta, fn _key, v1, v2 ->
        cond do
          # If either delta marks the key as removed, keep it as removed
          v1.action == :removed or v2.action == :removed ->
            %{action: :removed}

          # If both are modifications, merge their values
          v1.action == :modified and v2.action == :modified ->
            %{action: :modified, old_value: v1.old_value, value: v2.value}

          # Otherwise, prioritize the latest value
          true ->
            v2
        end
      end)
    end)
  end

  @spec format_delta(delta :: map(), context_id :: any()) :: list()
  def format_delta(delta, context_id) do
    formatter = Application.get_env(:knot, :delta_formatter, @default_formatter)
    formatter.format(delta, context_id)
  end
end
