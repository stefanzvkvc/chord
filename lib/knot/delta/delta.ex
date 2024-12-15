defmodule Knot.Delta do
  @moduledoc """
  Provides utilities for calculating, merging, and formatting context deltas.

  This module contains functions to:
  - Compute the differences (deltas) between two contexts.
  - Merge multiple deltas into a single representation.
  - Format deltas for communication or storage purposes.

  The formatting of deltas is customizable. Developers can define their own formatter module
  implementing the `Knot.Delta.Formatter.Behaviour` and configure it in their application.
  By default, the library uses `Knot.Delta.Formatter.Default`.
  """

  @default_formatter Knot.Delta.Formatter.Default

  @doc """
  Calculates the delta between two contexts.

  Given a `current_context` and a `new_context`, this function determines the differences:
  - Keys present in `new_context` but not in `current_context` are marked as `:added`.
  - Keys present in both but with differing values are marked as `:modified`.
  - Keys present in `current_context` but absent in `new_context` are marked as `:removed`.

  ## Parameters
    - `current_context` (map): The original context.
    - `new_context` (map): The updated context.

  ## Returns
    - (map): A map representing the delta, where each key maps to a change descriptor.

  ## Example
      iex> current_context = %{a: 1, b: 2, c: 3}
      iex> new_context = %{a: 1, b: 5, d: 4}
      iex> Knot.Delta.calculate_delta(current_context, new_context)
      %{
        b: %{action: :modified, old_value: 2, value: 5},
        c: %{action: :removed},
        d: %{action: :added, value: 4}
      }
  """
  @spec calculate_delta(current_context :: map(), new_context :: map()) :: map()
  def calculate_delta(current_context, new_context) do
    current_context = Map.new(current_context, fn {k, v} -> {k, v} end)
    new_context = Map.new(new_context, fn {k, v} -> {k, v} end)

    # Detect added and modified keys
    added_or_modified =
      Enum.reduce(new_context, %{}, fn {key, new_value}, acc ->
        case Map.get(current_context, key) do
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
      Enum.reduce(current_context, %{}, fn {key, _value}, acc ->
        if Map.has_key?(new_context, key) do
          acc
        else
          Map.put(acc, key, %{action: :removed})
        end
      end)

    # Combine results
    Map.merge(added_or_modified, removed)
  end

  @doc """
  Merges a list of deltas into a single delta.

  Combines multiple delta maps to produce a unified view of changes. The merging logic ensures:
  - If any delta marks a key as `:removed`, it takes precedence.
  - If multiple deltas modify the same key, the `old_value` is taken from the first modification,
    and the `value` from the last.
  - Otherwise, the latest change is retained.

  ## Parameters
    - `delta_list` (list of maps): A list of deltas to merge.

  ## Returns
    - (map): A single delta representing the merged changes.

  ## Example
      iex> delta1 = %{a: %{action: :added, value: 1}, b: %{action: :modified, old_value: 2, value: 3}}
      iex> delta2 = %{b: %{action: :removed}, c: %{action: :added, value: 4}}
      iex> Knot.Delta.merge_deltas([delta1, delta2])
      %{
        a: %{action: :added, value: 1},
        b: %{action: :removed},
        c: %{action: :added, value: 4}
      }
  """
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

  @doc """
  Formats a delta map for external communication or storage.

  Uses the configured delta formatter to transform the delta map into a desired format.
  By default, it uses `Knot.Delta.Formatter.Default`.

  ## Parameters
    - `delta` (map): The delta to format.
    - `context_id` (any): The context associated with the delta.

  ## Returns
    - (list): The formatted delta, as determined by the formatter module.

  ## Example
      iex> delta = %{a: %{action: :added, value: 1}, b: %{action: :removed}}
      iex> Knot.Delta.format_delta(delta, "game:1")
      [
        %{key: :a, action: :added, value: 1, context: "game:1"},
        %{key: :b, action: :removed, context: "game:1"}
      ]
  """
  @spec format_delta(delta :: map(), context_id :: any()) :: list()
  def format_delta(delta, context_id) do
    formatter = Application.get_env(:knot, :delta_formatter, @default_formatter)
    formatter.format(delta, context_id)
  end
end
