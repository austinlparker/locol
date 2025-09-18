# Build Setup

This document explains how to set up your environment for building locol from the command line.

## Environment Configuration

The build system requires Apple Developer credentials for code signing targets. These are configured via environment variables in a `.env` file.

### Quick Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your Apple Developer credentials:
   ```bash
   # Your Apple Developer Account ID (email)
   APPLE_ID=your.apple.id@example.com

   # Your Apple Developer Team ID (10-character alphanumeric string)
   TEAM_ID=YOUR_TEAM_ID

   # Optional: App-specific password for notarization
   APP_SPECIFIC_PASSWORD=your-app-specific-password
   ```

### Finding Your Credentials

- **APPLE_ID**: Your Apple Developer account email
- **TEAM_ID**: Found in Apple Developer portal > Membership details (10-character string like "ABCD123456")
- **APP_SPECIFIC_PASSWORD**: Generated at [appleid.apple.com](https://appleid.apple.com) > App-Specific Passwords (only needed for notarization)

## Make Targets

### Code Signing Required
These targets require the `.env` file with valid Apple Developer credentials:
- `make build` - Build the app in release mode
- `make archive` - Create an archive
- `make dmg` - Create a DMG installer
- `make notarize` - Notarize the DMG (requires APP_SPECIFIC_PASSWORD)

### No Code Signing Required
These targets work without Apple Developer credentials:
- `make clean` - Clean build artifacts
- `make components-db` - Build the OpenTelemetry component database
- `make lint` - Run SwiftLint (if installed)
- `make format` - Run SwiftFormat (if installed)

## Build Examples

```bash
# Clean and build from scratch
make clean
make build

# Build component database only
make components-db

# Full release process
make clean
make dmg
make notarize  # optional, requires APP_SPECIFIC_PASSWORD
```

## Security Notes

- The `.env` file is git-ignored and will not be committed
- Never commit your Apple Developer credentials to version control
- Use app-specific passwords instead of your main Apple ID password
- The `.env.example` file shows the required format but contains placeholder values