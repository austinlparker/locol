# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands
- Clean build artifacts: `make clean`
- Build app: `make build`
- Create app archive: `make archive`
- Create DMG: `make dmg`
- Notarize DMG: `make notarize`

## Testing Commands
- Run tests in Xcode: Select test in Test Navigator and run (CMD+U)
- Run single test: Select specific test method and run with CMD+U
- Verify test passing: Look for green checkmark in Test Navigator

## Code Style Guidelines
- Follow SwiftUI best practices for macOS development
- Use @Observable for view models, not @State for observation
- Pass dependencies via constructor for reference types
- Use Bindings only when child needs write access
- Use @Environment for app-wide state, @State for view-local state
- Optimize performance with LazyVStack/LazyHStack and stable identifiers
- Implement proper error handling with do/catch blocks
- Use modern Swift concurrency (async/await)
- Prioritize readability over performance
- Follow Swift naming conventions (camelCase)
- Add accessibility modifiers to all UI elements
- For test files: subclass XCTestCase, prefix methods with "test"