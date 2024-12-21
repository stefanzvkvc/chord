defmodule Chord.Utils.Time do
  @moduledoc """
  Default implementation of the `Chord.Utils.Time.Behaviour`.

  Provides time utilities for the library, leveraging Erlang's built-in
  time functions.

  ## Configuration

  By default, this module is used for time-based operations. If you wish to
  use a custom implementation, define a module adhering to the
  `Chord.Utils.Time.Behaviour` and configure it in your application:

      config :chord, :time, MyCustomTimeProvider

  ## Example

      iex> Chord.Utils.Time.current_time(:second)
      1672531200
  """

  @behaviour Chord.Utils.Time.Behaviour

  @doc """
  Returns the current time in the specified unit.

  ## Parameters

    - `unit` (:second | :millisecond): The desired unit for the time value.

  ## Returns

    - The current time as an integer, in the specified unit.

  ## Example

      iex> Chord.Utils.Time.current_time(:second)
      1672531200

      iex> Chord.Utils.Time.current_time(:millisecond)
      1672531200000
  """
  @impl true
  def current_time(:second), do: :os.system_time(:second)

  @impl true
  def current_time(:millisecond), do: :os.system_time(:millisecond)
end
