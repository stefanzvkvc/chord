defmodule Chord.Delta.Formatter.Behaviour do
  @moduledoc """
  Defines the behaviour for delta formatters.

  This behaviour allows developers to implement custom delta formatting logic
  tailored to their application's requirements. By adhering to this behaviour,
  developers can ensure that their formatter modules integrate seamlessly with Chord's
  delta management system.

  ## Example Implementation

      defmodule MyCustomFormatter do
        @behaviour Chord.Delta.Formatter.Behaviour

        @impl true
        def format(delta, context_id) do
          Enum.map(delta, fn {key, change} ->
            %{
              key: key,
              context: context_id,
              action: change.action,
              details: change
            }
          end)
        end
      end

  """

  @callback format(delta :: map(), context_id :: any()) :: list(map())
end
