ExUnit.start()
Application.put_env(:knot, :backend, Knot.Backend.Mock)
Application.put_env(:knot, :state_ttl, :timer.hours(6))
Application.put_env(:knot, :delta_ttl, :timer.hours(2))

Mox.defmock(Knot.Backend.Mock, for: Knot.Backend.Behaviour)
