# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2025-01-27
### New Features
- Added time_unit configuration to allow users to define the time unit (:second or :millisecond) for generating timestamps.

### Improvements
- Delta calculation now handles nested structures more effectively. Example:
  - Previous output:
    ```elixir
    %{a: %{value: %{b: %{c: %{d: "d"}}}, action: :added}}
    ```
  - New output:
    ```elixir
    %{a: %{b: %{c: %{d: %{value: "d", action: :added}}}}}
    ```
  This ensures a more logical representation of changes.
- The default delta formatter was redesigned to produce an output format that is easier to process, serialize, and consume. It now includes:
  - Simplified structures.
  - Improved usability for downstream consumers.
- Enhanced documentation across modules to improve usability and clarity.
- Other changes:
  - Various minor adjustments and refinements for consistency and maintainability.


## [0.1.4] - 2025-01-22
### Added
- Enhanced `README.md` with detailed examples for using the Chord library.
- Unit tests for `calculate_delta` to handle `nil` values and ensure proper behavior when handling nested maps.
- Project logo

### Changed
- Updated `delta_ttl` configuration to use seconds for consistency across the library.
- Improved `calculate_delta` function to:
  - Handle `nil` values appropriately.
  - Mark changes as `:modified` when the old value is `nil`.

### Fixed
- Bug in Redis backend:
  - `fetch_delta_counts/1` now correctly splits keys using `String.split/3` with `parts: 3` to handle keys with more than two colons.

## [0.1.3] - 2025-01-06
### Fixed
- Updated README.md to include missing details.

## [0.1.2] - 2025-01-06
### Fixed
- Fixed delta merging logic to correctly handle nested maps and ensure all changes are applied.

## [0.1.1] - 2025-01-05
### Fixed
- Corrected Redis configuration example in documentation.
- Fixed an issue in `Chord.Delta.calculate_delta/2` to correctly handle nested maps and avoid returning empty maps for unchanged nested structures.

## [0.1.0] - 2024-12-31
### Added
- Initial release of the Chord library.
- Real-time state synchronization with full and delta-based updates.
- Support for ETS and Redis backends.
- Developer-friendly APIs for setting, updating, and syncing contexts.
- Periodic cleanup of stale contexts and deltas.
- Support for context export and restore.
- Benchmark results showcasing performance for ETS and Redis under stateless and stateful architectures.
