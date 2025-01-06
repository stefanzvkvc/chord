# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
