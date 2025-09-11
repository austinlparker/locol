# Project Roadmap (Owner Priorities)

Actionable projects with “why” and “how”. P0 = highest priority.

2) Refactor components/abstractions and directory structure [P1]
- Why: Reduce coupling, clarify responsibilities, and make code discoverable.
- How:
  - Create folders/groups: `Core/` (logging, protocols), `Storage/` (GRDB types, migrations, stores), `OTLP/` (server, services, converter), `Features/Collectors/`, `Features/Telemetry/`, `UI/` (views), `Generated/` stays untouched.
  - Break up managers:
    - `CollectorManager` → orchestration only; persistence in `CollectorStore`, process in `ProcessManager`, downloads in `DownloadManager`.
    - Move YAML serialization concerns from manager to a small `ConfigRepository`.
  - Keep names and style per AGENTS.md; only relocate and split.

3) Clean up views and make previews work [P1]
- Why: Faster UI iteration and safer refactors.
- How:
  - Inject small fakes/mocks for `AppContainer`/protocols in `Preview Content` and `Helpers/` (e.g., `PreviewTelemetryStorage`, `PreviewCollectorStore`).
  - Ensure view state is decoupled from app singletons; use dependency injection.
  - Add `#Preview` blocks for `SidebarView`, `TelemetryView`, `SQLQueryView`, `AppSettingsView` with sample data.

4) Good tests for components [P1]
- Why: Prevent regressions as we refactor.
- How:
  - Add XCTest targets under `locolTests/` for: `ComponentDatabase`, `ConfigSnippetManager`, `OTLPConverter`, `ProcessManager` (fake file manager), `CollectorStore`.
  - Use fixtures under `Resources/fixtures/` (small YAML/JSON) and test doubles like `TelemetryViewerTests.FakeStorage`.
  - Add minimal E2E test for OTLP server behind `@available(macOS 15.0, *)` that injects a tiny request and asserts storage writes.

5) Improve dev experience (auto gen-grpc/swift) [P1]
- Why: Reduce setup friction and CI surprises.
- How:
  - CI: In `.github/workflows/build.yml`, add a step before build: `make gen-swift gen-grpc` and fail with a clear message if plugin/protoc missing.
  - Local: Document `brew install protoc protoc-gen-grpc-swift swiftlint swiftformat` and `git submodule update --init --recursive` in README.
  - Optional: Xcode Run Script Phase that checks for missing generated files and prints install guidance (avoid networked generation in Xcode to keep builds deterministic).

6) Improve SQL query/view (history, ergonomics) [P1]
- Why: Make analysis faster and reproducible.
- How:
  - Add `query_history(id, sql TEXT, created_at, collector_filter TEXT)` table; add `QueryHistoryStore` actor.
  - Update `SQLQueryView` to: show history list, re-run entries, and support `LIMIT/OFFSET` controls; keep execution via `TelemetryViewer`.
  - Harden `applyCollectorFilter` or replace with a small query-rewriter; extend `TelemetryViewerTests` for ORDER/GROUP/LIMIT edge cases.

7) Visualizations with SwiftUI Charts for time-series [P2]
- Why: Quick insight into metrics without leaving the app.
- How:
  - Use `Charts` (macOS 13+). Add a `MetricsChartView` that runs an aggregation SQL (e.g., bucketed minute sums/avg) and plots per service/metric.
  - Downsample in SQL to cap points; add toggles for window and rollup.

8) Apple Intelligence integration (NLQ → SQL) [P3]
- Why: Lower the barrier to explore data with natural language.
- How:
  - Define an `NLQService` protocol with a `generateSQL(from:)` async API and pluggable providers; feature-flag in settings.
  - Start with a lightweight, local heuristic provider (templates + synonyms) to keep offline; later, add an on-device model provider when an official API is available.
  - Add an NLQ prompt field in `SQLQueryView` that proposes SQL which users can edit before execution.

Backlog (from earlier suggestions)
- Retention scheduler + settings, export flow polish, accessibility/empty states, GRDB pragmas/WAL tuning, Homebrew cask, DMG SHA256 in CI, pipeline designer persistence.

Notes
- Do not edit `locol/Generated/`; regenerate via Makefile.
- Keep tests deterministic and fast under `locolTests/`.
- Component DB scripts require internet; provide offline fallback or cache when possible.
