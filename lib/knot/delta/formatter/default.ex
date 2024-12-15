defmodule Knot.Delta.Formatter.Default do
  @moduledoc """
  Default implementation for delta formatting.

  This module provides a straightforward and opinionated way to format deltas into a list of maps.
  Each map describes a change to a specific key in the context, including metadata such as the action
  performed (e.g., `:added`, `:modified`, `:removed`) and the associated `context_id`.

  The formatting is intended to be extensible, allowing developers to substitute this formatter
  with a custom implementation by defining their own module and setting it in the application configuration.

  ## Example
      iex> delta = %{
      ...>   a: %{action: :added, value: 1},
      ...>   b: %{action: :modified, old_value: 2, value: 3},
      ...>   c: %{action: :removed}
      ...> }
      iex> context_id = "game:1"
      iex> Knot.Delta.Formatter.Default.format(delta, context_id)
      [
        %{key: :a, action: :added, value: 1, context: "game:1"},
        %{key: :b, action: :modified, old_value: 2, value: 3, context: "game:1"},
        %{key: :c, action: :removed, context: "game:1"}
      ]
  """

  @behaviour Knot.Delta.Formatter.Behaviour

  @doc """
  Formats the given delta into a standardized list of maps.

  This implementation adds the `context_id` to each change and formats changes as follows:
  - For `:added`, includes the new `value`.
  - For `:modified`, includes both the `old_value` and the new `value`.
  - For `:removed`, includes only the `key` and `context_id`.

  ## Parameters
    - `delta` (map): The delta map representing changes to the context.
    - `context_id` (any): The context ID to associate with each change.

  ## Returns
    - (list of maps): A list of formatted changes.

  ## Example
      iex> delta = %{
      ...>   a: %{action: :added, value: 1},
      ...>   b: %{action: :modified, old_value: 2, value: 3},
      ...>   c: %{action: :removed}
      ...> }
      iex> Knot.Delta.Formatter.Default.format(delta, "game:1")
      [
        %{key: :a, action: :added, value: 1, context: "game:1"},
        %{key: :b, action: :modified, old_value: 2, value: 3, context: "game:1"},
        %{key: :c, action: :removed, context: "game:1"}
      ]
  """
  @spec format(map(), any()) :: list(map())
  @impl true
  def format(delta, context_id) do
    Enum.map(delta, fn {key, change} ->
      base = %{
        key: key,
        action: change.action,
        context: context_id
      }

      case change.action do
        :added -> Map.put(base, :value, change.value)
        :modified -> Map.merge(base, %{old_value: change.old_value, value: change.value})
        :removed -> base
      end
    end)
  end
end
