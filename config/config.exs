import Config

config :knot,
  backend: Knot.Backend.ETS,
  # Default to 10 if not explicitly configured
  delta_threshold: 10
