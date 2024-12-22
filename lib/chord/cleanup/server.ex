defmodule Chord.Cleanup.Server do
  @moduledoc """
  Periodic cleanup server for stale contexts and deltas.

  This server periodically triggers the cleanup logic defined in `Chord.Cleanup`,
  removing stale entries from the backend and optionally exporting active contexts.

  ## State
  The server's state includes:
    - `:interval` - The interval (in milliseconds) between cleanup executions.
    - `:backend_opts` - A keyword list of options passed to backend listing functions.

  ## Example

      Chord.Cleanup.Server.start_link(interval: :timer.minutes(30), backend_opts: [limit: 100])
  """

  use GenServer
  alias Chord.Cleanup

  @default_interval :timer.hours(1)

  @doc """
  Starts the cleanup server with the specified options.

  ## Options
    - `:interval` (integer): Time interval in milliseconds for periodic cleanup (default: 1 hour).
    - `:backend_opts` (Keyword.t): Options passed to backend listing functions (see "Common Options" in the `Chord` module).
    - `:export_callback` (function): Optional function to export active contexts before deletion.

  ## Example

      iex> Chord.Cleanup.Server.start_link(interval: :timer.minutes(30), backend_opts: [limit: 50])
      {:ok, pid}
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  Updates the interval for periodic cleanup at runtime.

  ## Parameters
    - `new_interval` (integer): The new interval in milliseconds.

  ## Returns
    - `:ok` if the interval was successfully updated.
  """
  def update_interval(new_interval) do
    GenServer.call(__MODULE__, {:update_interval, new_interval})
  end

  @doc """
  Updates the backend options for periodic cleanup at runtime.

  ## Parameters
    - `new_opts` (Keyword.t): The new backend options.

  ## Returns
    - `:ok` if the backend options were successfully updated.
  """
  def update_backend_opts(new_opts) do
    GenServer.call(__MODULE__, {:update_backend_opts, new_opts})
  end

  @doc """
  Updates the export callback for active context exporting.

  ## Parameters
    - `export_callback` (function): The new export callback function.

  ## Returns
    - `:ok` if the export callback was successfully updated.
  """
  def update_export_callback(export_callback) do
    GenServer.call(__MODULE__, {:update_export_callback, export_callback})
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    backend_opts = Keyword.get(opts, :backend_opts, [])
    export_callback = Keyword.get(opts, :export_callback)

    schedule_cleanup(interval)
    {:ok, %{interval: interval, backend_opts: backend_opts, export_callback: export_callback}}
  end

  @impl true
  def handle_call({:update_interval, new_interval}, _from, state) do
    {:reply, :ok, %{state | interval: new_interval}}
  end

  @impl true
  def handle_call({:update_backend_opts, new_opts}, _from, state) do
    {:reply, :ok, %{state | backend_opts: new_opts}}
  end

  @impl true
  def handle_call({:update_export_callback, export_callback}, _from, state) do
    {:reply, :ok, %{state | export_callback: export_callback}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    opts = state.backend_opts
    export_callback = state.export_callback

    # Pass export_callback to the cleanup logic
    opts = Keyword.put(opts, :export_callback, export_callback)
    Cleanup.periodic_cleanup(opts)

    schedule_cleanup(state.interval)
    {:noreply, state}
  end

  def handle_info(_unknown_message, state) do
    {:noreply, state}
  end

  @doc false
  defp schedule_cleanup(interval) do
    Process.send_after(self(), :cleanup, interval)
  end
end