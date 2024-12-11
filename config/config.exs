import Config

config :knot,
  backend: Knot.Backend.ETS,
  # Time-based state cleanup
  state_ttl: :timer.hours(6),
  # Time-based state cleanup
  delta_ttl: :timer.hours(2),
  # Number of versions to retain
  delta_threshold: 100,
  # Default implementation for delta formatting
  delta_formatter: Knot.Delta.Formatter.Default
