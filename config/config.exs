import Config

config :logger, :console,
  format: "$time [$level] $metadata$message\n",
  metadata: [:module, :function]

config :chord,
  backend: Chord.Backend.Redis,
  # Context retention policy
  context_auto_delete: false,
  # Time-based state cleanup
  context_ttl: nil,
  # Time-based delta cleanup
  delta_ttl: :timer.hours(24),
  # Number of versions to retain
  delta_threshold: 100,
  # Default implementation for delta formatting
  delta_formatter: Chord.Delta.Formatter.Default,
  # Default time provider
  time_provider: Chord.Utils.Time
