# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

.PHONY: all clean build archive dmg notarize gen-swift gen-grpc clean-proto build-plugins lint format precommit install-hooks components-db components-db-clean

# Only require Apple signing env vars for code-signing related targets
NEED_CODESIGN_TARGETS := build_deps build archive export dmg notarize
ifneq (,$(filter $(MAKECMDGOALS),$(NEED_CODESIGN_TARGETS)))
REQUIRED_ENV_VARS := APPLE_ID TEAM_ID
$(foreach var,$(REQUIRED_ENV_VARS),$(if $(value $(var)),,$(error $(var) is undefined)))
endif

# Variables
APP_NAME = locol
SCHEME = $(APP_NAME)
PROJECT = $(APP_NAME).xcodeproj
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(APP_NAME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/export
DMG_PATH = $(BUILD_DIR)/$(APP_NAME).dmg

# Protobuf generation variables
PROTO_SRC_DIR = opentelemetry-proto/opentelemetry/proto
PROTO_GEN_SWIFT_DIR = locol/Generated

# Default target
all: dmg

# Build protoc plugins  
build-plugins:
	@echo "Building protoc plugins from project dependencies..."
	@xcodebuild -scheme locol -derivedDataPath build -configuration Debug build

# Generate Swift protobuf files
gen-swift:
	@echo "Generating Swift protobuf files..."
	@mkdir -p $(PROTO_GEN_SWIFT_DIR)
	@find $(PROTO_SRC_DIR) -name "*.proto" -exec protoc \
		--proto_path=opentelemetry-proto \
		--swift_out=$(PROTO_GEN_SWIFT_DIR) \
		--swift_opt=Visibility=Public \
		{} +
	@echo "Swift protobuf files generated in $(PROTO_GEN_SWIFT_DIR)"

# Generate gRPC Swift files
gen-grpc:
	@echo "Generating gRPC Swift files..."
	@mkdir -p $(PROTO_GEN_SWIFT_DIR)
	@# First try homebrew-installed plugin
	@PLUGIN_PATH=$$(which protoc-gen-grpc-swift-2 2>/dev/null); \
	if [ -z "$$PLUGIN_PATH" ]; then \
		PLUGIN_PATH="/opt/homebrew/bin/protoc-gen-grpc-swift-2"; \
	fi; \
	if [ -z "$$PLUGIN_PATH" ]; then \
		PLUGIN_PATH=$$(find build -name "protoc-gen-grpc-swift-2" -type f 2>/dev/null | head -1); \
	fi; \
	if [ -n "$$PLUGIN_PATH" ] && [ -x "$$PLUGIN_PATH" ]; then \
		echo "Using plugin at: $$PLUGIN_PATH"; \
		find $(PROTO_SRC_DIR)/collector -name "*_service.proto" -exec protoc \
			--plugin=$$PLUGIN_PATH \
			--proto_path=opentelemetry-proto \
			--grpc-swift-2_out=$(PROTO_GEN_SWIFT_DIR) \
			--grpc-swift-2_opt=Visibility=Public \
			{} +; \
	else \
		echo "protoc-gen-grpc-swift-2 plugin not found. Install with: brew install protoc-gen-grpc-swift"; \
		exit 1; \
	fi
	@echo "gRPC Swift files generated in $(PROTO_GEN_SWIFT_DIR)"

# Clean generated protobuf files
clean-proto:
	rm -rf $(PROTO_GEN_SWIFT_DIR)

# Clean build artifacts
clean: clean-proto
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
build: gen-swift gen-grpc build_deps
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
# Lint Swift sources using SwiftLint
lint:
	@if command -v swiftlint >/dev/null 2>&1; then \
		printf "Running SwiftLint...\n"; \
		swiftlint --config .swiftlint.yml; \
	else \
		echo "SwiftLint not installed. Install with: brew install swiftlint"; \
		echo "Skipping lint."; \
	fi

# Format Swift sources using SwiftFormat
format:
	@if command -v swiftformat >/dev/null 2>&1; then \
		printf "Running SwiftFormat...\n"; \
		swiftformat . --config .swiftformat; \
	else \
		echo "SwiftFormat not installed. Install with: brew install swiftformat"; \
		echo "Skipping format."; \
	fi

# Run both format and lint (useful locally and in CI)
precommit: format lint

# Install git hooks for pre-commit formatting and linting
install-hooks:
	@chmod +x scripts/pre-commit || true
	@ln -sf scripts/pre-commit .git/hooks/pre-commit
	@echo "Git pre-commit hook installed."

# Build the OpenTelemetry component database used by the app
components-db:
	@echo "Building component database..."
	@bash scripts/extract_all_versions.sh

# Clean generated component database and temporary JSONs
components-db-clean:
	@echo "Cleaning component database artifacts..."
	@rm -f Resources/components.db scripts/configs_*.json
