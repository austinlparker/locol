# Repository Guidelines

## Project Structure & Module Organization
- `locol/`: Swift sources (SwiftUI + AppKit). Key folders: `Views/`, `Models/`, `Helpers/`, `Resources/`, `Assets.xcassets/`.
- `locol/Generated/`: Protobuf and gRPC Swift stubs. Do not edit by hand; regenerate via Makefile.
- `locolTests/`: XCTest suites (e.g., `MetricFilterTests.swift`). Add new tests here.
- `opentelemetry-proto/`: Git submodule containing `.proto` definitions.
- Build artifacts and dependencies live under `build/`. Build scripts: `Makefile`, `build.sh`.

## Build, Test, and Development Commands
- Initialize submodules: `git submodule update --init --recursive` — fetches OpenTelemetry protos.
- Generate protobufs: `make gen-swift` and `make gen-grpc` — requires `protoc` and `protoc-gen-grpc-swift-2` in PATH.
- Build app: `make build` — Release build; uses automatic signing. Requires `.env` with `APPLE_ID` and `TEAM_ID`.
- Create installer: `make dmg` — exports and builds a DMG (installs `create-dmg` via npm if missing).
- Clean: `make clean` (artifacts) and `make clean-proto` (generated sources).
- Run tests: `xcodebuild test -project locol.xcodeproj -scheme locol -destination 'platform=macOS'`.

## Coding Style & Naming Conventions
- Swift 5 conventions, 2‑space indentation, line length ~120. Favor SwiftUI patterns used in the repo.
- Naming: Types `UpperCamelCase`, properties/methods `lowerCamelCase`, views end with `View`, test types end with `Tests`.
- Do not modify files in `locol/Generated/`; regenerate instead.
- Prefer small extensions and focused files inside `Helpers/` and `Models/`.

## Testing Guidelines
- Framework: XCTest in `locolTests/` with file names like `FeatureNameTests.swift`.
- Keep tests deterministic and fast; cover parsing, filtering, and table/outline data models.
- Run locally via the `xcodebuild test` command above. Add fixtures under `Resources/` if needed.

## Commit & Pull Request Guidelines
- Commits: imperative mood and concise scope (e.g., "Fix layout jitter in TelemetryView").
- PRs: include a clear description, linked issues, steps to verify, and screenshots/GIFs for UI changes.
- Before opening: ensure tests pass and `make build` succeeds; call out any proto changes and regeneration steps.

## Security & Configuration Tips
- Do not commit secrets. Use `.env` for `APPLE_ID`, `TEAM_ID`, and (optionally) `APP_SPECIFIC_PASSWORD` for notarization.
- Verify toolchain availability: `protoc`, `protoc-gen-grpc-swift-2`, Xcode command line tools, and `create-dmg`.
