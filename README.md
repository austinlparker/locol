# locol

Manage your local OpenTelemetry collectors on macOS.

## Features

- Configure and run multiple collectors.
- View collector metrics and logs in real-time.
- Easily add pre-configured snippets to your collector config.

## Development

### Requirements

- macOS 14 or later
- Xcode 15 or later
- Apple Developer account for signing and notarization

### Building

Clone the repository and open `locol.xcodeproj` in Xcode. You can then build and run the project directly from Xcode.

### CI/CD

The project uses GitHub Actions for continuous integration and deployment. The workflow:

1. Builds and tests the application on every push and pull request
2. On the main branch, additionally:
   - Creates a signed and notarized DMG
   - Uploads the DMG as a build artifact

Required GitHub secrets for CI/CD:

- `BUILD_CERTIFICATE_BASE64`: Developer ID certificate (base64 encoded)
- `MAC_DEV_CERTIFICATE_BASE64`: Mac Development certificate (base64 encoded)
- `CERT_PASSWORD`: Password for both certificates
- `APPLE_ID`: Apple ID email
- `TEAM_ID`: Apple Developer Team ID
- `APP_SPECIFIC_PASSWORD`: App-specific password for Apple ID

## Project Structure

- `Models/`: Data models and business logic
- `Views/`: SwiftUI views and view models
- `Helpers/`: Extensions and utility functions
- `Resources/`: Assets and configuration templates
