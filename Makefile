# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

.PHONY: all clean build archive dmg notarize

# Check for required environment variables
REQUIRED_ENV_VARS := APPLE_ID TEAM_ID
$(foreach var,$(REQUIRED_ENV_VARS),$(if $(value $(var)),,$(error $(var) is undefined)))

# Variables
APP_NAME = locol
SCHEME = $(APP_NAME)
PROJECT = $(APP_NAME).xcodeproj
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/export
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg

# Default target
all: dmg

# Clean build artifacts
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)

# Build dependencies with automatic signing
build_deps:
	xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination "platform=macOS,arch=arm64" \
		-destination "platform=macOS,arch=x86_64" \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		OTHER_SWIFT_FLAGS="-D RELEASE" \
		-skipPackagePluginValidation \
		ONLY_ACTIVE_ARCH=NO \
		ENABLE_BITCODE=NO \
		DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

# Build the app in release mode
build: build_deps
	xcodebuild clean build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		-destination "platform=macOS,arch=arm64" \
		-destination "platform=macOS,arch=x86_64" \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		OTHER_SWIFT_FLAGS="-D RELEASE" \
		-skipPackagePluginValidation \
		ONLY_ACTIVE_ARCH=NO \
		ENABLE_BITCODE=NO \
		DEBUG_INFORMATION_FORMAT=dwarf-with-dsym

# Create an archive
archive: build_deps
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-archivePath $(ARCHIVE_PATH) \
		-destination "generic/platform=macOS" \
		CODE_SIGN_STYLE=Automatic \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		OTHER_SWIFT_FLAGS="-D RELEASE" \
		SKIP_INSTALL=NO \
		BUILD_LIBRARIES_FOR_DISTRIBUTION=YES \
		-skipPackagePluginValidation \
		ONLY_ACTIVE_ARCH=NO \
		ENABLE_BITCODE=NO \
		DEBUG_INFORMATION_FORMAT=dwarf-with-dsym \
		COPY_PHASE_STRIP=NO \
		STRIP_INSTALLED_PRODUCT=NO

# Export the app from the archive
export: archive
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportOptionsPlist ExportOptions.plist \
		-exportPath $(EXPORT_PATH) \
		-allowProvisioningUpdates

# Create DMG using create-dmg
dmg: export
	which create-dmg || npm install -g create-dmg
	create-dmg \
		--overwrite \
		$(EXPORT_PATH)/$(APP_NAME).app \
		$(BUILD_DIR)
	@echo "DMG created at $(DMG_PATH)"

# Notarize the DMG (optional)
notarize: dmg
ifdef APP_SPECIFIC_PASSWORD
	xcrun notarytool submit $(DMG_PATH) \
		--apple-id "$(APPLE_ID)" \
		--password "$(APP_SPECIFIC_PASSWORD)" \
		--team-id "$(TEAM_ID)" \
		--wait
	xcrun stapler staple $(DMG_PATH)
	@echo "DMG notarized and stapled at $(DMG_PATH)"
else
	@echo "Skipping notarization (APP_SPECIFIC_PASSWORD not set)"
endif 