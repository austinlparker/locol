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

## Libraries and Documentation

- Documentation exists for GRDB and GRDB libraries in `docs`
- Use MCP tools to search Apple Developer documentation when needed.

# Modern Swift Development

Write idiomatic SwiftUI code following Apple's latest architectural recommendations and best practices.

## Core Philosophy

- SwiftUI is the default UI paradigm for Apple platforms - embrace its declarative nature
- Avoid legacy UIKit patterns and unnecessary abstractions
- Focus on simplicity, clarity, and native data flow
- Let SwiftUI handle the complexity - don't fight the framework

## Architecture Guidelines

### 1. Embrace Native State Management

Use SwiftUI's built-in property wrappers appropriately:
- `@State` - Local, ephemeral view state
- `@Binding` - Two-way data flow between views
- `@Observable` - Shared state
- `@Environment` - Dependency injection for app-wide concerns

### 2. State Ownership Principles

- Views own their local state unless sharing is required
- State flows down, actions flow up
- Keep state as close to where it's used as possible
- Extract shared state only when multiple views need it

### 3. Modern Async Patterns

- Use `async/await` as the default for asynchronous operations
- Leverage `.task` modifier for lifecycle-aware async work
- Avoid Combine unless absolutely necessary
- Handle errors gracefully with try/catch

### 4. View Composition

- Build UI with small, focused views
- Extract reusable components naturally
- Use view modifiers to encapsulate common styling
- Prefer composition over inheritance

### 5. Code Organization

- Organize by feature, not by type (avoid Views/, Models/, ViewModels/ folders)
- Keep related code together in the same file when appropriate
- Use extensions to organize large files
- Follow Swift naming conventions consistently

## Implementation Patterns

### Simple State Example
```swift
struct CounterView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") {
                count += 1
            }
        }
    }
}
```

### Shared State with @Observable
```swift
@Observable
class UserSession {
    var isAuthenticated = false
    var currentUser: User?

    func signIn(user: User) {
        currentUser = user
        isAuthenticated = true
    }
}

struct MyApp: App {
    @State private var session = UserSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
```

### Async Data Loading
```swift
struct ProfileView: View {
    @State private var profile: Profile?
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let profile {
                ProfileContent(profile: profile)
            } else if let error {
                ErrorView(error: error)
            }
        }
        .task {
            await loadProfile()
        }
    }

    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        do {
            profile = try await ProfileService.fetch()
        } catch {
            self.error = error
        }
    }
}
```

## Best Practices

### DO:
- Write self-contained views when possible
- Use property wrappers as intended by Apple
- Test logic in isolation, preview UI visually
- Handle loading and error states explicitly
- Keep views focused on presentation
- Use Swift's type system for safety

### DON'T:
- Create ViewModels for every view
- Move state out of views unnecessarily
- Add abstraction layers without clear benefit
- Use Combine for simple async operations
- Fight SwiftUI's update mechanism
- Overcomplicate simple features

## Testing Strategy

- Unit test business logic and data transformations
- Use SwiftUI Previews for visual testing
- Test @Observable classes independently
- Keep tests simple and focused
- Don't sacrifice code clarity for testability

## Modern Swift Features

- Use Swift Concurrency (async/await, actors)
- Leverage Swift 6 data race safety when available
- Utilize property wrappers effectively
- Embrace value types where appropriate
- Use protocols for abstraction, not just for testing

## Summary

Write SwiftUI code that looks and feels like SwiftUI. The framework has matured significantly - trust its patterns and tools. Focus on solving user problems rather than implementing architectural patterns from other platforms.
