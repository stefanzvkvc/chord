defmodule Chord.Support.MocksHelpers.Time do
  @moduledoc false
  def mock_time(opts, times \\ 1) do
    unit = Keyword.get(opts, :unit)
    time = Keyword.get(opts, :time)
    Mox.expect(Chord.Support.Mocks.Time, :current_time, times, fn ^unit -> time end)
  end
end
