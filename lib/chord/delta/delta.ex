defmodule Chord.Delta do
  @moduledoc """
  Provides utilities for calculating, merging, and formatting context deltas.

  This module contains functions to:
  - Compute the differences (deltas) between two contexts.
  - Merge multiple deltas into a single representation.
  - Format deltas for communication or storage purposes.

  The formatting of deltas is customizable. Developers can define their own formatter module
  implementing the `Chord.Delta.Formatter.Behaviour` and configure it in their application.
  By default, the library uses `Chord.Delta.Formatter.Default`.
  """

  @default_formatter Chord.Delta.Formatter.Default

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
      iex> Chord.Delta.calculate_delta(current_context, new_context)
      %{
        b: %{action: :modified, old_value: 2, value: 5},
        c: %{action: :removed, old_value: 3},
        d: %{action: :added, value: 4}
      }
  """
  @spec calculate_delta(current_context :: map(), new_context :: map()) :: map()
  def calculate_delta(current_context, new_context)
      when is_map(current_context) and is_map(new_context) and current_context == new_context,
      do: %{}

  def calculate_delta(current_context, new_context)
      when is_map(current_context) and is_map(new_context) do
    # Detect added and modified keys
    added_or_modified =
      Enum.reduce(new_context, %{}, fn {key, new_value}, acc ->
        old_value = Map.get(current_context, key)

        cond do
          is_map(old_value) and is_map(new_value) ->
            nested_delta = calculate_delta(old_value, new_value)

            if nested_delta == %{} do
              acc
            else
              Map.put(acc, key, nested_delta)
            end

          is_map_key(current_context, key) and old_value != new_value ->
            Map.put(acc, key, %{
              action: :modified,
              old_value: old_value,
              value: new_value
            })

          is_nil(old_value) ->
            delta =
              if is_map(new_value) do
                calculate_delta(%{}, new_value)
              else
                %{action: :added, value: new_value}
              end

            Map.put(acc, key, delta)

          true ->
            acc
        end
      end)

    # Detect removed keys
    current_keys = Map.keys(current_context)

    removed =
      Enum.reduce(current_keys, %{}, fn key, acc ->
        if Map.has_key?(new_context, key) do
          acc
        else
          Map.put(acc, key, %{action: :removed, old_value: Map.get(current_context, key)})
        end
      end)

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
      iex> delta2 = %{b: %{action: :removed, old_value: 3}, c: %{action: :added, value: 4}}
      iex> Chord.Delta.merge_deltas([delta1, delta2])
      %{
        a: %{action: :added, value: 1},
        b: %{action: :removed, old_value: 3},
        c: %{action: :added, value: 4}
      }
  """
  @spec merge_deltas(delta_list :: list(map())) :: map()
  def merge_deltas(delta_list) do
    Enum.reduce(delta_list, %{}, fn delta, acc ->
      Map.merge(acc, delta, fn _key, v1, v2 ->
        cond do
          v1[:action] == :removed or v2[:action] == :removed ->
            %{action: :removed, old_value: v2[:old_value]}

          v1[:action] == :modified or v2[:action] == :modified ->
            %{action: :modified, old_value: v2.old_value, value: v2.value}

          is_map(v1) and is_map(v2) ->
            merge_deltas([v1, v2])

          true ->
            v2
        end
      end)
    end)
  end

  @doc """
  Formats a delta map for external use using the configured delta formatter.

  This function delegates the formatting process to the delta formatter configured in your application.
  By default, it uses the `Chord.Delta.Formatter.Default` module, but you can provide a custom formatter
  to handle deltas according to your application's requirements.

  The `metadata` parameter provides flexibility for passing additional information to the formatter.
  While common keys like `:context_id` and `:version` are supported by the default formatter,
  custom formatters can utilize any metadata relevant to their implementation.

  ## Parameters
    - `delta` (map): The delta map representing changes to the context.
    - `metadata` (map): A dynamic map containing additional information for the formatter. Common keys include:
      - `:context_id` - The identifier of the context.
      - `:version` - The version of the context being formatted.

  ## Returns
    - A formatted map or any structure returned by the configured formatter.
  """
  @spec format_delta(delta :: map(), metadata :: any()) :: any()
  def format_delta(delta, metadata) do
    formatter = Application.get_env(:chord, :delta_formatter, @default_formatter)
    formatter.format(delta, metadata)
  end
end
