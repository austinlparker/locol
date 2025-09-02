# CRUSH.md

## Build Commands
- Clean build: `make clean`
- Build app: `make build`
- Create archive: `make archive`
- Create DMG: `make dmg`
- Notarize DMG: `make notarize` (requires APP_SPECIFIC_PASSWORD env var)

## Testing Commands
- Run all tests: In Xcode, press CMD+U
- Run single test: Click test method name in Test Navigator, press CMD+U
- Run test file: Select file in Test Navigator, press CMD+U

## Code Style Guidelines
- **State Management**: Use `@Observable` for view models, not `@State` for observation
- **Dependencies**: Pass via constructor for reference types, use Bindings only for write access
- **Naming**: Follow Swift conventions (camelCase for properties/methods, PascalCase for types)
- **Error Handling**: Use do/catch blocks with proper error propagation
- **Concurrency**: Use async/await for asynchronous operations
- **Performance**: Use LazyVStack/LazyHStack for lists, stable ForEach identifiers
- **Accessibility**: Add modifiers to all UI elements, support Dynamic Type
- **Testing**: Subclass XCTestCase, prefix test methods with "test", use @testable import
- **Imports**: Group by standard library, third-party, then local modules
- **No TODOs**: Fully implement all functionality without placeholders