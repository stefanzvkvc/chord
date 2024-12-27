# Chord: Sync, Manage, and Harmonize Contexts 🎵

Welcome to **Chord** — a flexible and powerful Elixir library designed to simplify context management and delta tracking in your distributed or real-time applications.

## 🎯 Why Chord?
When you need a solution for real-time state synchronization, partial updates, and efficient cleanup, Chord strikes the perfect note! Here’s what makes Chord special:

- **Seamless State Sync**: Keep your clients up-to-date with full context or delta-based updates.
- **Customizable Backend**: Use ETS, Redis, or your own backend implementation.
- **Flexible Delta Formatting**: Define how your updates are structured.
- **Periodic Cleanup**: Automatically clear stale contexts or deltas.
- **Developer-Friendly APIs**: Simple, consistent, and easy-to-use APIs.
- **Context Export and Restore**: Export contexts to or restore them from external providers.
- **Partial Updates**: Apply updates to specific fields within a context.

---

## 🚀 Getting Started

### 1️⃣ Install the Library
Add Chord to your Mix dependencies:

```elixir
def deps do
  [
    {:chord, "~> 0.1.0"}
  ]
end
```

Run:

```bash
mix deps.get
```

### 2️⃣ Configure Chord
Add your desired configuration in `config/config.exs`:

```elixir
config :chord,
  backend: Chord.Backend.ETS,            # Choose your backend (Redis, ETS, etc.)
  context_auto_delete: false,            # Enable or disable auto-deletion of old contexts
  context_ttl: :timer.hours(6),          # Time-to-live for contexts
  delta_ttl: :timer.hours(24),           # Time-to-live for deltas
  delta_threshold: 100,                  # Number of deltas to retain
  delta_formatter: Chord.Delta.Formatter.Default, # Format for deltas
  time_provider: Chord.Utils.Time,       # Time provider for consistent timestamps
  export_callback: nil,                  # Optional: Define a callback for exporting contexts
  context_external_provider: nil         # Optional: Define a function for fetching external contexts
```

---

## 🎹 How to Use Chord

### Setting a Context
```elixir
{:ok, result} = Chord.set_context("user:123", %{status: "online"})
IO.inspect(result, label: "Context Set")
```

### Updating a Context
```elixir
{:ok, result} = Chord.update_context("user:123", %{status: "away"})
IO.inspect(result, label: "Context Updated")
```

### Synchronizing State
```elixir
case Chord.sync_context("user:123", nil) do
  {:full_context, context} -> IO.inspect(context, label: "Full Context")
  {:delta, delta} -> IO.inspect(delta, label: "Delta Update")
  {:no_change, version} -> IO.puts("No changes for version #{version}")
end
```

### Exporting a Context
```elixir
:ok = Chord.export_context("user:123")
```

### Restoring a Context
```elixir
{:ok, restored_context} = Chord.restore_context("user:123")
IO.inspect(restored_context, label: "Restored Context")
```

### Cleanup Operations
Run periodic cleanup to remove stale data:

```elixir
Chord.cleanup(limit: 50)
```

### Managing the Cleanup Server
Start and manage the Cleanup Server for automated periodic cleanup:

```elixir
{:ok, _pid} = Chord.start_cleanup_server(interval: :timer.minutes(30))
Chord.update_cleanup_interval(:timer.minutes(60))
Chord.update_cleanup_backend_opts(limit: 100)
Chord.stop_cleanup_server()
```

---

## 🛠️ Customization

### Backends
Chord supports multiple backends out-of-the-box:

- **ETS** (In-Memory)
- **Redis** (Distributed)

You can implement your own backend by adhering to the `Chord.Backend.Behaviour`.

### Delta Formatters
Customize how deltas are structured by implementing the `Chord.Delta.Formatter` behaviour.

## ⚡ Features at a Glance

| Feature                  | Description                                      |
|--------------------------|--------------------------------------------------|
| **Real-Time Sync**       | Delta-based and full-context synchronization.    |
| **Customizable Backends**| Redis, ETS, or your own custom backend.          |
| **Periodic Cleanup**     | Automatically remove stale data.                 |
| **Partial Updates**      | Update only specific fields in a context.        |
| **Delta Tracking**       | Efficiently track and retrieve state changes.    |
| **Context Export**       | Export context to external storage.              |
| **Context Restore**      | Restore context from external providers.         |

---

## 📚 Documentation
TODO

---

## 🛡️ Testing
Chord comes with a robust suite of tests to ensure reliability. Run tests with:

```bash
mix test
```

---

🎵 *"Let Chord orchestrate your state management with precision and elegance."*
