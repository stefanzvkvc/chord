defmodule Chord.Utils.Redis.Behaviour do
  @moduledoc """
  Defines the behavior for Redis client operations.
  """

  @callback command([String.t()]) :: {:ok, any()} | {:error, any()}
end
