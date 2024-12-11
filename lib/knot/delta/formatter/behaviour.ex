defmodule Knot.Delta.Formatter.Behaviour do
  @moduledoc """
  Defines the behaviour for delta formatters.
  """

  @callback format(delta :: map(), context_id :: any()) :: any()
end
