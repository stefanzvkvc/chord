<p align="center">
  <img src="https://raw.githubusercontent.com/stefanzvkvc/chord/main/assets/chord.png" alt="Chord Logo" width="300">
</p>

Welcome to **Chord** - a flexible and powerful Elixir library designed to simplify context management and delta tracking in your distributed or real-time applications.

[![Hex.pm](https://img.shields.io/hexpm/v/chord.svg)](https://hex.pm/packages/chord) [![Documentation](https://img.shields.io/badge/documentation-hexdocs-blue)](https://hexdocs.pm/chord)

## Why Chord?
When you need a solution for real-time state synchronization, partial updates, and efficient cleanup, Chord strikes the perfect note! Here’s what makes Chord special:

- **Seamless state sync**: Keep your clients up-to-date with full context or delta-based updates.
- **Customizable backend**: Use ETS, Redis, or your own backend implementation.
- **Flexible delta formatting**: Define how your updates are structured.
- **Periodic cleanup**: Automatically clear stale contexts or deltas.
- **Developer-friendly APIs**: Simple, consistent, and easy-to-use APIs.
- **Context export and restore**: Export contexts to or restore them from external providers.
- **Partial updates**: Apply updates to specific fields within a context.
- **Delta Tracking**: Efficiently track and retrieve state changes.
- **Flexible architecture**: Chord works in both stateful (via GenServer) and stateless modes (direct calls to backends like Redis or ETS). This flexibility makes it easier to adapt Chord to a variety of use cases.

---

## Getting started

### Install the library
Add Chord to your Mix dependencies:

```elixir
def deps do
  [
    {:chord, "~> 0.2.0"}
  ]
end
```

Run:

```bash
mix deps.get
```

### Configure Chord
Add your desired configuration in `config/config.exs`:

```elixir
config :chord,
  backend: Chord.Backend.ETS,                     # Choose the backend (ETS, Redis, etc.)
  context_auto_delete: false,                     # Enables automatic deletion of old contexts
  context_ttl: 6 * 60 * 60,                       # Context time-to-live (follows `time_unit` format)
  delta_ttl: 24 * 60 * 60,                        # Delta time-to-live (follows `time_unit` format)
  delta_threshold: 100,                           # Maximum number of deltas to retain
  delta_formatter: Chord.Delta.Formatter.Default, # Default delta formatter; customizable
  time_provider: Chord.Utils.Time,                # Default time provider; customizable
  time_unit: :second,                             # Time unit (:second or :millisecond) for timestamps
  export_callback: nil,                           # Callback for persisting contexts
  context_external_provider: nil                  # Function for fetching external contexts
```

Explanation:
  - **context_auto_delete**: Optional but recommended for efficient memory management.
    - If enabled, the following options must also be set:
      - **context_ttl**: Defines the time-to-live for contexts.
      - **delta_ttl**: Specifies the time-to-live for deltas.
      - **delta_threshold**: Determines the maximum number of deltas to retain.
  - **context_ttl** & **delta_ttl**: Specify lifetimes for contexts and deltas. The values should align with the unit set in time_unit.
  - **delta_formatter**: A default delta formatter is provided, but you can implement a custom formatter to suit your needs.
  - **time_provider**: Responsible for generating timestamps. You can replace the default with a custom time provider.
  - **time_unit**: Specifies the time unit for timestamps. Options are :second or :millisecond.
  - **export_callback**: Define this callback to persist contexts from memory to an external storage solution.
  - **context_external_provider**: Use this to retrieve contexts from external sources when needed.

---

## How to use Chord
In Chord, a **context** is basically a container for state. The term **“context”** might mean different things in various fields, but in Chord, it specifically means a **container for state**. Here are some examples to explain this idea:

- In a **chat application**, a context could be a group chat, including its details (e.g., participants, topic), and messages.
- In a **game session**, a context might hold the game’s state, like player positions, scores, and progress.
- In a **collaborative document editor**, a context could be the document’s state, keeping track of edits, updates, and collaborators.

With this understanding of the term, let's look at some practical examples.

### Setting a context
Define the global context and track changes with deltas.

```elixir
Chord.set_context("user:369", %{status: "online", metadata: %{theme: "light", language: "en-US"}})
{:ok,
 %{
   context: %{
     version: 1,
     context: %{
       status: "online",
       metadata: %{language: "en-US", theme: "light"}
     },
     context_id: "user:369",
     inserted_at: 1737901562
   },
   delta: %{
     version: 1,
     context_id: "user:369",
     delta: %{
       status: %{value: "online", action: :added},
       metadata: %{
         language: %{value: "en-US", action: :added},
         theme: %{value: "light", action: :added}
       }
     },
     inserted_at: 1737901562
   }
 }}
```

### Updating a context
Updates a portion of the global context associated with a specific identifier.
This function allows for partial modifications without affecting the entire context.

```elixir
Chord.update_context("user:369", %{metadata: %{theme: "dark"}})
{:ok,
 %{
   context: %{
     version: 2,
     context: %{status: "online", metadata: %{language: "en-US", theme: "dark"}},
     context_id: "user:369",
     inserted_at: 1737901601
   },
   delta: %{
     version: 2,
     context_id: "user:369",
     delta: %{
       metadata: %{
         theme: %{value: "dark", action: :modified, old_value: "light"}
       }
     },
     inserted_at: 1737901601
   }
 }}
```

### Getting a context
Fetches the current state for a specified identifier.

```elixir
Chord.get_context("user:369")
{:ok,
 %{
   version: 2,
   context: %{status: "online", metadata: %{language: "en-US", theme: "dark"}},
   context_id: "user:369",
   inserted_at: 1737901601
 }}
```

### Synchronizing state
Synchronize the state for a given identifier.
Depending on the version the client has, it will receive either the full context, only the changes (deltas), or a notification that there are no updates.

```elixir
Chord.sync_context("user:369", nil)
{:full_context,
 %{
   version: 2,
   context: %{status: "online", metadata: %{language: "en-US", theme: "dark"}},
   context_id: "user:369",
   inserted_at: 1737901601
 }}

Chord.sync_context("user:369", 1)
{:delta,
 %{
   version: 2,
   context_id: "user:369",
   delta: %{
     metadata: %{theme: %{value: "dark", action: :modified, old_value: "light"}}
   },
   inserted_at: 1737901601
 }}

Chord.sync_context("user:369", 2)
{:no_change, 2}
```

### Exporting a context
Save the current context for a specific identifier to external storage using the configured export callback.

#### Defining the export callback
To enable the export functionality, you need to define a callback function in your application. This function will handle how the context is exported (e.g., saving it to a database). Here’s an example:

```elixir
defmodule MyApp.ContextExporter do
  @moduledoc """
  Handles exporting contexts to external storage.
  """

  @spec export_context(map()) :: :ok | {:error, term()}
  def export_context(context_data) do
    %{context_id: context_id, version: verion, context: context} = context_data
    # Example: Save context_data to an external database or storage
    case ExternalStorage.save(context_id, context, version) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### Configure the export callback
Next, configure the export callback in your application’s environment. This tells Chord how to handle context exports.

```elixir
# config/config.exs
config :chord, :export_callback, &MyApp.ContextExporter.export_context/1
```

#### Use Chord.export_context/1
Once the callback is configured, you can use function to export a specific context to external storage:

```elixir
Chord.export_context("user:369")
:ok
```

### Deleting a context
Removes the entire context and its associated deltas.

```elixir
Chord.delete_context("user:369")
:ok
```

### Restoring a context
Retrieve and restore a context from an external provider to the current backend.

#### Define the restore callback
First, define a module and function that will handle the logic for retrieving a context. For example:

```elixir
defmodule MyApp.ContextRestorer do
  @moduledoc """
  Handles restoring contexts from external storage.
  """

  @spec restore_context(String.t()) :: {:ok, map()} | {:error, term()}
  def restore_context(context_id) do
    # Example: Retrieve the context from a database or other storage system
    case ExternalStorage.get(context_id) do
      {:ok, %{context: context, version: version}} -> {:ok, %{context: context, version: version}}
      {:error, reason} -> {:error, reason}
    end
  end
end
```

#### Configure the restore callback
Next, configure the restore callback in your application’s environment. This tells Chord how to handle context restoration:

```elixir
# config/config.exs
config :chord, :context_external_provider, &MyApp.ContextRestorer.restore_context/1
```

#### Use Chord.restore_context/1
Once the callback is configured, you can use function to retrieve and restore a specific context:

```elixir
Chord.restore_context("user:369")
{:ok,
 %{
   version: 10,
   context: %{source: "external storage provider"},
   inserted_at: 1737464001,
   context_id: "user:369"
 }}
```

### Cleanup operations
Chord provides cleanup functionality to remove stale contexts and deltas. To enable and configure this feature, add the following settings to your application configuration:

#### Configuration options

```elixir
config :chord,
  context_auto_delete: true, # Enable or disable auto-deletion of old contexts
  context_ttl: 6 * 60 * 60,  # Time-to-live for contexts
  delta_ttl: 24 * 60 * 60,   # Time-to-live for deltas
  delta_threshold: 100       # Number of delta versions to retain (optional)
```

#### How it works
- Context cleanup:
  - Set **context_auto_delete: true** to enable context cleanup.
  - Configure **context_ttl** to define how long contexts should remain in memory before being deleted.
  - When a context is deleted, all associated deltas are automatically cleaned up as well.

- Delta cleanup:
  - To clean deltas by age, set **delta_ttl** to specify the maximum time deltas should remain in memory.
  - To clean deltas by number, set **delta_threshold** to define the maximum number of deltas to retain.

> **Note:** If the configured time unit is set to second, related configurations such as context_ttl and delta_ttl will also need to be specified in second to ensure consistency.

#### Example usage
Run the cleanup process manually with:

```elixir
Chord.cleanup(limit: 50)
```

### Managing the cleanup server
Start and manage the Cleanup Server for automated periodic cleanup:

```elixir
{:ok, _pid} = Chord.start_cleanup_server(interval: :timer.minutes(30))
Chord.update_cleanup_interval(:timer.minutes(60))
Chord.update_cleanup_backend_opts(limit: 100)
Chord.stop_cleanup_server()
```

---

## Customization

### Backends
A **backend** refers to the underlying data storage mechanism responsible for managing and persisting context and delta data. Backends allow Chord to be flexible and adaptable to different storage solutions, whether in-memory, on disk, or external services.

Chord supports multiple backends out-of-the-box:

- **ETS** (In-Memory): No additional setup is required.
- **Redis** (Distributed): Requires a Redis instance and some configuration.

#### Using Redis as a backend
To use Redis as the backend for Chord, follow these steps:

1. **Start Redis**: Ensure a Redis server is running.
2. **Set up the Redis connection**: Start a Redis connection process using the Redix library, which is included with Chord:

```elixir
{:ok, _} = Redix.start_link("redis://localhost:6379", name: :my_redis)
```

3. **Configure Chord to use Redis**: Set the Redis client and backend in your application’s

```elixir
# config/config.exs
config :chord,
  backend: Chord.Backend.Redis,
  redis_client: :my_redis
```

You can also implement your own backend by adhering to the `Chord.Backend.Behaviour`.

### Delta formatters
Chord provides the ability to define custom delta formatters by implementing the `Chord.Delta.Formatter.Behaviour`. This feature is useful for tailoring how deltas (changes) are formatted to suit your application’s requirements.

#### Defining a custom delta formatter
To define a custom delta formatter, create a module that implements the `Chord.Delta.Formatter.Behaviour`:

```elixir
defmodule MyApp.CustomFormatter do
  @moduledoc """
  A custom delta formatter for Chord, demonstrating how to implement the behavior.
  """

  @behaviour Chord.Delta.Formatter.Behaviour

  @impl true
  def format(delta, _context_id \\ nil) do
    flatten_delta(delta, [])
  end

  defp flatten_delta(delta, path) when is_map(delta) do
    Enum.flat_map(delta, fn {key, value} ->
      new_path = path ++ [key]

      if is_map(value) and Map.has_key?(value, :action) do
        [format_change(new_path, value)]
      else
        flatten_delta(value, new_path)
      end
    end)
  end

  defp format_change(path, %{action: action} = change) do
    base = %{key: path, action: action}

    case action do
      :added -> Map.put(base, :value, change.value)
      :modified -> Map.merge(base, %{old_value: change.old_value, value: change.value})
      :removed -> Map.put(base, :old_value, change.old_value)
    end
  end
end
```

#### Configuring Chord to use your delta formatter
Once you’ve defined your custom formatter, configure Chord to use it by setting it in the application environment:

```elixir
# config/config.exs
config :chord, :delta_formatter, MyApp.CustomFormatter
```

#### Example usage

```elixir
delta = %{
  a: %{
    f: %{value: "new", action: :added},
    b: %{
      c: %{
        d: %{value: "2", action: :modified, old_value: "1"},
        e: %{action: :removed, old_value: "3"}
      }
    }
  }
}

MyApp.CustomFormatter.format(delta)
[
  %{value: "new", key: [:a, :f], action: :added},
  %{value: "2", key: [:a, :b, :c, :d], action: :modified, old_value: "1"},
  %{key: [:a, :b, :c, :e], action: :removed, old_value: "3"}
]
```

### Custom time provider
Chord allows you to define custom time provider by implementing the `Chord.Utils.Time.Behaviour`. This feature is useful for customizing time-based operations, such as timestamp generation and for mocking time in tests.

#### Defining a custom time provider
To define your custom time provider, create a module that implements the `Chord.Utils.Time.Behaviour`:

```elixir
defmodule MyApp.CustomTimeProvider do
  @moduledoc """
  A custom time provider for Chord, demonstrating how to implement the behavior.
  """

  @behaviour Chord.Utils.Time.Behaviour

  @impl true
  def current_time(:second) do
    # Example: Use a custom logic for time in seconds
    DateTime.utc_now() |> DateTime.to_unix(:second)
  end

  @impl true
  def current_time(:millisecond) do
    # Example: Use a custom logic for time in milliseconds
    DateTime.utc_now() |> DateTime.to_unix(:millisecond)
  end
end
```

#### Configuring Chord to use your time provider

```elixir
# config/config.exs
config :chord, :time_provider, MyApp.CustomTimeProvider
```

---

## Benchmark results: Redis and ETS performance

Chord has been tested to ensure solid performance in both Redis (single-node setup for now, with plans for distributed scenarios) and ETS (in-memory, single-node applications). Here’s how it performs under various scenarios:

## Scenarios tested

### 1. Stateless operations
These scenarios simulate operations without maintaining a dedicated process per context. All updates, syncs and state modifications happen directly through the library’s API.

- **Single context (50 participants)**: Represents a single group chat or meeting with 50 participants frequently updating their status, typing indicators, or syncing state.
- **Multiple contexts (100 contexts)**: Simulates 100 independent group chats or meetings being updated simultaneously.

### 2. Stateful operations
These scenarios introduce a process per context (e.g., a GenServer for each group chat). Each participant interacts with this stateful process and the process uses Chord’s API to manage context.

- **Single context (50 participants)**: A single group chat or meeting managed by a GenServer, handling frequent updates and syncs from 50 participants.
- **Multiple contexts (100 contexts)**: Simulates 100 group chats or meetings, each managed by its own GenServer, handling participant interactions.

## Results

### Redis backend (single node)

> **Note:** Redis benchmarks were conducted in a single-node configuration to evaluate baseline performance. While Redis is designed for distributed systems, a fully distributed environment is not yet implemented in the benchmark script. Plans are underway to expand the benchmarking script to support distributed scenarios.

| **Scenario**                       | **Operations/sec** | **Average Time** | **Notes**                                        |
|------------------------------------|--------------------|------------------|--------------------------------------------------|
| Stateless - Single Context (50)    | 92.89 ops/s        | 10.77 ms         | Handles concurrent operations efficiently.       |
| Stateful - Single Context (50)     | 18.80 ops/s        | 53.19 ms         | Performance impacted by GenServer overhead.      |
| Stateful - Multiple Contexts (100) | 1.72 ops/s         | 581.46 ms        | Slower due to process sync overhead.             |
| Stateless - Multiple Contexts (100)| 1.57 ops/s         | 635.29 ms        | Poor throughput under high multi-context load.   |

### ETS Backend (In-Memory, Single-Node)

| **Scenario**                       | **Operations/sec** | **Average Time** | **Notes**                                        |
|------------------------------------|--------------------|------------------|--------------------------------------------------|
| Stateless - Single Context (50)    | 230.61 ops/s       | 4.34 ms          | Extremely fast for single-node setups.           |
| Stateful - Single Context (50)     | 54.34 ops/s        | 18.40 ms         | GenServer overhead slows performance.            |
| Stateful - Multiple Contexts (100) | 5.66 ops/s         | 176.81 ms        | Scales well but slower with 100 contexts.        |
| Stateless - Multiple Contexts (100)| 4.69 ops/s         | 213.18 ms        | Limited scalability for multi-context updates.   |

## Key insights

### Redis:
- **Single-node performance**: Reflects the baseline for Redis's capability, with potential for distributed scaling in the future.
- **Stateless operations** Outperform stateful ones when multiple clients update a single context concurrently. The absence of GenServer synchronization overhead makes Redis particularly well-suited for high-frequency, multi-client updates to shared contexts.
- **Stateful performance bottlenecks**: Syncing multiple contexts (100) causes significant performance degradation due to process synchronization and network overhead.
- **Future improvements**: A distributed Redis setup would allow benchmarking its true scalability and potential for handling high-throughput, multi-context scenarios.

### ETS:
- **Optimal for single-node applications**: Outshines Redis in single-node scenarios, particularly in stateless operations where 50 participants concurrently update a single context, achieving 230.61 ops/sec with just 4.34 ms latency.
- **GenServer overhead**: Stateful operations see reduced performance due to process-based synchronization, especially with many contexts (e.g., 100).
- **Scalability limitations**: While ETS is efficient for localized, single-node setups, it struggles with multi-context workloads, where its performance drops to 4.69 ops/sec for stateless and 5.66 ops/sec for stateful scenarios.

## Choosing between stateless and stateful

### Stateless:
- Directly interacts with Chord’s API, bypassing the need for per-context processes.
- **Best for**: High-concurrency scenarios where multiple clients update a single shared context. Performance degrades under high multi-context workloads, particularly in Redis.

### Stateful:
- Manages a dedicated GenServer per context (e.g., per group chat or meeting).
- **Best for**: Scenarios requiring additional application-level state or business logic. However, high-concurrency and multi-context workloads may lead to significant performance degradation.

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

**Benchmark Suite Configuration**:
- **Warmup**: 2 seconds
- **Execution Time**: 5 seconds
- **Parallel**: 1
- **Inputs**: Data

---

## Contributing

Contributions from the community are welcome to make Chord even better! Whether it's fixing bugs, improving documentation, or adding new features, your help is greatly appreciated.

### How to contribute
1. Fork the repository.
2. Create a new branch for your changes.
3. Make your changes and test them thoroughly.
4. Submit a pull request with a clear description of your changes.

Feel free to open issues for discussion or if you need help. Together, we can build something amazing!

---

## Testing
Chord comes with a robust suite of tests to ensure reliability. Run tests with:

```bash
mix test
```

---

🎵 *"Let Chord orchestrate your state management with precision and elegance."*
