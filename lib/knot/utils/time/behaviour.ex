defmodule Knot.Utils.Time.Behaviour do
  @moduledoc """
  Defines the behavior for time utilities used by the library.

  This behavior allows developers to implement custom time providers,
  making it easier to handle time-based operations (e.g., cleanup) and mock
  time in tests.

  ## Example

      defmodule MyCustomTimeProvider do
        @behaviour Knot.Utils.Time.Behaviour

        @impl true
        def current_time(:second) do
          # Custom logic for returning current time
          DateTime.utc_now() |> DateTime.to_unix(:second)
        end

        @impl true
        def current_time(:millisecond) do
          # Custom logic for millisecond precision
          DateTime.utc_now() |> DateTime.to_unix(:millisecond)
        end
      end
  """

  @callback current_time(:second | :millisecond) :: integer()
end
