import Config

config :logger, :console,
  format: "$time [$level] $metadata$message\n",
  metadata: [:module, :function]

config :chord,
  # Default backend
  backend: Chord.Backend.ETS,

  # Context retention policy
  # Auto-deletion disabled by default, giving users control over cleanup
  context_auto_delete: false,

  # Context Time-to-Live
  # Default is nil, allowing users to specify their own retention policy if needed
  context_ttl: nil,

  # Delta Time-to-Live
  # Retain deltas for 24 hours; suitable for most real-time applications
  delta_ttl: :timer.hours(24),

  # Number of versions to retain
  # Retain 100 versions as a balance between storage use and rollback capability
  delta_threshold: 100,

  # Default delta formatter
  # Include the default implementation for deltas
  delta_formatter: Chord.Delta.Formatter.Default,

  # Default time provider
  # Allows for extensibility while using a built-in time provider by default
  time_provider: Chord.Utils.Time,

  # Default export callback
  # Keep it `nil`, giving users flexibility to define their export needs
  export_callback: nil,

  # External context provider
  # Defaults to `nil`, users can set this to fetch context from external systems
  context_external_provider: nil
