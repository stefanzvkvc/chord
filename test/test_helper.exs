ExUnit.start()

# Shared helper functions
defmodule TestHelpers do
  # General Utilities
  def allow_sharing_expectation(mock, owner_pid, allowed_via) do
    Mox.allow(mock, owner_pid, allowed_via)
  end
end
