defmodule Chord.Utils.Context.MapTransform do
  @moduledoc """
  Utilities for manipulating nested maps, including deep merging.
  """

  @doc """
  Performs a deep merge of two maps.

  Nested maps are merged recursively. Non-map values in `map2` overwrite values in `map1`.

  ## Parameters
  - `map1`: The base map.
  - `map2`: The map with updates or additional keys.

  ## Examples

      iex> map1 = %{a: %{b: %{c: 1}}, d: 4}
      iex> map2 = %{a: %{b: %{c: 42, e: 99}}, d: 5, f: 10}
      iex> Chord.Utils.Context.MapUtils.deep_merge(map1, map2)
      %{a: %{b: %{c: 42, e: 99}}, d: 5, f: 10}

      iex> map1 = %{a: 1}
      iex> map2 = %{a: %{b: 2}}
      iex> Chord.Utils.Context.MapUtils.deep_merge(map1, map2)
      %{a: %{b: 2}}
  """
  def deep_merge(map1, map2) when is_map(map1) and is_map(map2) do
    Map.merge(map1, map2, fn _key, val1, val2 ->
      if is_map(val1) and is_map(val2) do
        deep_merge(val1, val2)
      else
        val2
      end
    end)
  end

  def deep_merge(_map1, _map2) do
    raise ArgumentError, "deep_merge expects both arguments to be maps"
  end
end
