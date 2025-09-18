# Architecture Overview

This document summarizes the high-level module boundaries and dependency flow for the app.

## Modules (Folders)
- Core: Shared protocols, errors, logging, and dependency injection (AppContainer, Environment keys).
- Storage: GRDB-backed database code (schema, migrations, repositories) implementing the `Storage` protocol.
- OTLP: OTLP server and ingestion pipeline (internal mapping from protobufs to domain/storage models).
- Features/Collectors: Collector orchestration (process/download) using `ProcessManaging` and `Downloading`.
- Features/Telemetry: Feature code for telemetry-centric behaviors (queries and transforms for UI consumption).
- UI: All SwiftUI view code and small view helpers.
- Generated: Protobuf/gRPC generated code (never edited by hand).

## Dependency Direction
- UI → Core protocols via Environment (AppContainer)
- Features → Core protocols (Storage, ProcessManaging, Downloading, optional ConfigRepository)
- OTLP → Core (uses Storage) and Generated types internally
- Storage → Core (implements `Storage`)
- Generated → used by OTLP only; no other module depends on it directly

## State & Concurrency
- Views: use @State/@Binding/@Observable per SwiftUI guidance; inject dependencies with @Environment.
- Async work: use async/await; prefer actors where mutable shared state exists (e.g., ProcessManaging internals).

## Test Strategy
- Unit test Storage queries and persistence, ProcessManaging behavior, Downloading, ConfigRepository round-trips.
- Contract test for OTLP ingestion path (request → persisted rows) without exposing extra protocols.
- SwiftUI previews use small fakes injected via Environment.

