defmodule Chord.Utils.Redis.Client do
  @moduledoc """
  Wrapper around Redis commands to abstract interaction and enable easier testing.
  """

  require Logger

  @doc """
  Executes a Redis command.

  Depending on the configuration, this function will:
  - Interact with the named Redix process (using `Process.whereis/1`).
  - Use a mock module for testing.

  ## Parameters
    - `command` (list): The Redis command to execute.

  ## Returns
    - `{:ok, result}` on success.
    - `{:error, reason}` on failure.
  """
  def command(command) do
    case redis_connection() do
      pid when is_pid(pid) ->
        execute_redis_command(pid, command)

      module when is_atom(module) ->
        module.command(command)

      nil ->
        {:error, :process_not_found}
    end
  end

  defp execute_redis_command(pid, command) do
    case Redix.command(pid, command) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.error("Redis command failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp redis_connection() do
    case Application.get_env(:chord, :redis_client) do
      name when is_atom(name) ->
        Process.whereis(name) || name

      other ->
        Logger.warning("Invalid redis_client configuration: #{inspect(other)}")
        nil
    end
  end
end
