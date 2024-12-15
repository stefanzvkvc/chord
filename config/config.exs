import Config

config :knot,
  backend: Knot.Backend.ETS,
  # Context retention policy
  context_auto_delete: false,
  # Time-based state cleanup
  context_ttl: nil,
  # Time-based state cleanup
  delta_ttl: :timer.hours(2),
  # Number of versions to retain
  delta_threshold: 100,
  # Default implementation for delta formatting
  delta_formatter: Knot.Delta.Formatter.Default
