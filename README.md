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
    {:chord, "~> 0.1.3"}
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

## 🕰 Benchmark Results

Chord has been benchmarked using Redis and ETS backends under both stateless and stateful architectures. Below are the results for various scenarios:

### Redis Benchmark Results

#### With Input Data

| Scenario                                             | IPS    | Avg. Time | Deviation | Median Time | 99th Percentile |
|------------------------------------------------------|--------|-----------|-----------|-------------|-----------------|
| Stateless - Single Context (50 participants)         | 62.79  | 15.93 ms  | ±18.03%   | 15.88 ms    | 22.99 ms        |
| Stateful - Single Context (50 participants)          | 7.69   | 130.07 ms | ±51.34%   | 102.08 ms   | 270.40 ms       |
| Stateless - Multiple Contexts (100 contexts)         | 2.08   | 481.38 ms | ±3.48%    | 474.73 ms   | 511.20 ms       |
| Stateful - Multiple Contexts (100 contexts)          | 1.85   | 541.19 ms | ±3.51%    | 541.24 ms   | 566.32 ms       |

**Comparison:**
- Stateless - Single Context: 62.79x faster than Stateful - Multiple Contexts.

### ETS Benchmark Results

#### With Input Data

| Scenario                                             | IPS    | Avg. Time | Deviation | Median Time | 99th Percentile |
|------------------------------------------------------|--------|-----------|-----------|-------------|-----------------|
| Stateless - Single Context (50 participants)         | 151.19 | 6.61 ms   | ±20.47%   | 6.46 ms     | 14.43 ms        |
| Stateful - Single Context (50 participants)          | 29.56  | 33.82 ms  | ±13.06%   | 36.05 ms    | 45.56 ms        |
| Stateless - Multiple Contexts (100 contexts)         | 3.51   | 284.85 ms | ±14.28%   | 279.17 ms   | 405.34 ms       |
| Stateful - Multiple Contexts (100 contexts)          | 3.73   | 268.05 ms | ±23.67%   | 237.10 ms   | 374.59 ms       |

**Comparison:**
- Stateless - Single Context: 43.07x faster than Stateful - Multiple Contexts.

### Device Information

| Property                   | Value                    |
|----------------------------|--------------------------|
| **Operating System**       | macOS                    | 
| **CPU Information**        | Apple M4 Pro             |
| **Number of Cores**        | 12                       |
| **Available Memory**       | 24 GB                    |
| **Elixir Version**         | 1.17.3                   |
| **Erlang Version**         | 27.1.2                   |
| **JIT Enabled**            | True                     |

**Benchmark Suite Configuration:**
- **Warmup:** 2 seconds
- **Execution Time:** 5 seconds
- **Parallel:** 1
- **Inputs:** Data

---

## 🧰 Contributing

Contributions from the community are welcome to make Chord even better! Whether it's fixing bugs, improving documentation, or adding new features, your help is greatly appreciated.

### How to Contribute
1. Fork the repository.
2. Create a new branch for your changes.
3. Make your changes and test them thoroughly.
4. Submit a pull request with a clear description of your changes.

Feel free to open issues for discussion or if you need help. Together, we can build something amazing!

---

## 🛡️ Testing
Chord comes with a robust suite of tests to ensure reliability. Run tests with:

```bash
mix test
```

---

🎵 *"Let Chord orchestrate your state management with precision and elegance."*
