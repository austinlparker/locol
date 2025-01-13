# Variables
PROJECT = locol.xcodeproj
SCHEME = locol
BUILD_DIR = build
CONFIGURATION ?= Release
DERIVED_DATA = $(BUILD_DIR)
APP_NAME = locol.app
PRODUCT_PATH = $(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(APP_NAME)

# Default target
.PHONY: all
all: build

# Clean build directory
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)

# Build the app
.PHONY: build
build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(DERIVED_DATA)

# Run tests
.PHONY: test
test:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-derivedDataPath $(DERIVED_DATA)

# Create archive for distribution
.PHONY: archive
archive:
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-archivePath $(BUILD_DIR)/$(SCHEME).xcarchive

# Show build settings
.PHONY: settings
settings:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings

# Show available schemes
.PHONY: list
list:
	xcodebuild -project $(PROJECT) -list

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  make          - Builds the app in Release configuration"
	@echo "  make clean    - Cleans build directory"
	@echo "  make test     - Runs tests"
	@echo "  make archive  - Creates archive for distribution"
	@echo "  make settings - Shows build settings"
	@echo "  make list     - Lists available schemes"
	@echo ""
	@echo "Options:"
	@echo "  CONFIGURATION=(Debug|Release) - Build configuration"
