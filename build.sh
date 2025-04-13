#!/bin/bash
set -e

# Configuration
APP_NAME="locol"
SCHEME="locol"
PROJECT="${APP_NAME}.xcodeproj"
ARCHIVE_PATH="./build/${APP_NAME}.xcarchive"
EXPORT_PATH="./build/export"
DMG_PATH="./build/${APP_NAME}.dmg"

# Check environment variables
if [ -z "$TEAM_ID" ]; then
  echo "Error: TEAM_ID environment variable not set"
  echo "Please set TEAM_ID, APPLE_ID, and optionally APP_SPECIFIC_PASSWORD"
  exit 1
fi

# Clean build directory
rm -rf build
mkdir -p build

# Archive the application
echo "Creating archive..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  SKIP_INSTALL=NO \
  BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
  -skipPackagePluginValidation \
  ONLY_ACTIVE_ARCH=NO

# Export the application
echo "Exporting application..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$EXPORT_PATH" \
  -allowProvisioningUpdates

# Create DMG
echo "Creating DMG..."
which create-dmg || npm install -g create-dmg
create-dmg \
  --overwrite \
  "$EXPORT_PATH/${APP_NAME}.app" \
  "$DMG_PATH"

# Notarize if credentials are available
if [ ! -z "$APPLE_ID" ] && [ ! -z "$APP_SPECIFIC_PASSWORD" ]; then
  echo "Submitting for notarization..."
  xcrun notarytool submit "$DMG_PATH" \
    --team-id "$TEAM_ID" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --wait
  
  echo "Stapling notarization ticket..."
  xcrun stapler staple "$DMG_PATH"
  
  echo "✅ Notarization complete!"
else
  echo "⚠️ Skipping notarization (missing credentials)"
fi

echo "✅ Build complete! DMG available at: $DMG_PATH"