defmodule Chord.Utils.Redis.Client do
  @moduledoc """
  Wrapper around Redix to abstract Redis commands and enable easier mocking in tests.
  """
  require Logger
  @behaviour Chord.Utils.Redis.Behaviour

  @impl true
  def command(command) do
    case redis_connection() do
      pid when is_pid(pid) ->
        case Redix.command(pid, command) do
          {:ok, result} ->
            {:ok, result}

          {:error, reason} ->
            Logger.error("Redis command failed: #{inspect(reason)}")
            {:error, reason}
        end

      module when is_atom(module) ->
        # Call the mock's implementation
        module.command(command)
    end
  end

  defp redis_connection() do
    case Application.get_env(:chord, :redis_client) do
      pid when is_pid(pid) ->
        pid

      module when is_atom(module) ->
        module

      nil ->
        raise "Redis client is not configured. Please set :redis_client in the application environment."
    end
  end
end
