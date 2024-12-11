defmodule Knot.Cleanup.Server do
  @moduledoc """
  Periodic cleanup server for stale states and deltas.
  """

  use GenServer
  alias Knot.Cleanup

  @default_interval :timer.hours(1)

  @doc """
  Starts the cleanup server with the specified options.

  Options:
    - `:interval` - Time interval in milliseconds for periodic cleanup (default: 1 hour).
    - `:backend_opts` - Options to pass to the backend's listing functions.

  ## Example

      Knot.Cleanup.Server.start_link(interval: :timer.minutes(30))
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    schedule_cleanup(interval)
    {:ok, %{interval: interval, backend_opts: Keyword.get(opts, :backend_opts, [])}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    Cleanup.periodic_cleanup(state.backend_opts)
    schedule_cleanup(state.interval)
    {:noreply, state}
  end

  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end
