defmodule Knot.Delta.Formatter.Default do
  @moduledoc """
  Default implementation for delta formatting.
  """
  @behaviour Knot.Delta.Formatter.Behaviour

  @doc """
  Formats the delta.
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
