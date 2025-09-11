#!/bin/bash

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$SCRIPT_DIR/../.work"
COLLECTOR_DIR="$WORK_DIR/opentelemetry-collector"
CONTRIB_DIR="$WORK_DIR/opentelemetry-collector-contrib"
OUTPUT_DIR="$SCRIPT_DIR/../Resources"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# Log to stderr to avoid contaminating command substitution outputs
log() {
    >&2 echo -e "$(timestamp) ${GREEN}[INFO]${NC} $1"
}

warn() {
    >&2 echo -e "$(timestamp) ${YELLOW}[WARN]${NC} $1"
}

error() {
    >&2 echo -e "$(timestamp) ${RED}[ERROR]${NC} $1"
}

# Get the 10 most recent versions from GitHub API
get_recent_versions() {
    log "Fetching recent collector versions from GitHub..."
    local versions
    versions=$(curl -s https://api.github.com/repos/open-telemetry/opentelemetry-collector/releases | \
        jq -r '.[].tag_name' | head -10)
    
    if [ -z "$versions" ] || [ "$versions" = "null" ]; then
        error "Failed to fetch versions from GitHub API"
        error "Please check your internet connection and try again"
        exit 1
    fi
    
    echo "$versions"
}

# Versions to extract (10 most recent)
log "Getting recent collector versions..."
# Read versions line-by-line to avoid word splitting on spaces
IFS=$'\n' read -r -d '' -a VERSIONS < <(get_recent_versions; printf '\0')
log "Will extract versions: ${VERSIONS[*]}"

# Create work directory
setup_work_dir() {
    log "Setting up work directory..."
    mkdir -p "$WORK_DIR"
    mkdir -p "$OUTPUT_DIR"
}

# Clone or update repositories
clone_repos() {
    log "Setting up repositories..."
    
    if [ ! -d "$COLLECTOR_DIR" ]; then
        log "Cloning opentelemetry-collector..."
        git clone https://github.com/open-telemetry/opentelemetry-collector.git "$COLLECTOR_DIR"
    else
        log "Updating opentelemetry-collector..."
        cd "$COLLECTOR_DIR"
        git fetch --all --tags
        cd - > /dev/null
    fi
    
    if [ ! -d "$CONTRIB_DIR" ]; then
        log "Cloning opentelemetry-collector-contrib..."
        git clone https://github.com/open-telemetry/opentelemetry-collector-contrib.git "$CONTRIB_DIR"
    else
        log "Updating opentelemetry-collector-contrib..."
        cd "$CONTRIB_DIR"
        git fetch --all --tags
        cd - > /dev/null
    fi
}

# Extract configs for a specific version
extract_version() {
    local version=$1
    log "Extracting configs for $version..."
    
    # Checkout collector version - exact match only
    cd "$COLLECTOR_DIR"
    git fetch --all --tags >/dev/null 2>&1
    
    if ! git checkout "$version" >/dev/null 2>&1; then
        error "Failed to checkout exact version $version in collector repository"
        cd - > /dev/null
        return 1
    fi
    
    local collector_commit=$(git rev-parse HEAD)
    log "Collector at commit: ${collector_commit:0:8}"
    
    # Checkout contrib version - exact match only
    cd "$CONTRIB_DIR"
    git fetch --all --tags >/dev/null 2>&1
    
    if ! git checkout "$version" >/dev/null 2>&1; then
        error "Failed to checkout exact version $version in contrib repository"
        cd - > /dev/null
        return 1
    fi
    
    local contrib_commit=$(git rev-parse HEAD)
    log "Contrib at commit: ${contrib_commit:0:8}"
    
    cd "$SCRIPT_DIR"
    
    # Run extraction
    local output_file="configs_${version}.json"
    # Default to quiet extractor unless explicitly overridden by VERBOSE/DEBUG
    if [ "${VERBOSE:-0}" = "1" ] || [ "${DEBUG:-0}" = "1" ]; then
        LOCOL_DEBUG=1
    else
        LOCOL_DEBUG=0
    fi
    log "Running config extraction (LOCOL_DEBUG=${LOCOL_DEBUG})..."
    if [ "$LOCOL_DEBUG" = "1" ]; then
        >&2 echo "go run extract_configs.go --version=$version --collector-path=$COLLECTOR_DIR --contrib-path=$CONTRIB_DIR --output=$output_file"
    fi
    LOCOL_DEBUG="$LOCOL_DEBUG" go run extract_configs.go \
        --version="$version" \
        --collector-path="$COLLECTOR_DIR" \
        --contrib-path="$CONTRIB_DIR" \
        --output="$output_file"
    
    local extract_result=$?
    
    if [ $extract_result -eq 0 ]; then
        # Check if we actually got components
        local component_count=$(jq '.components | length' "$output_file" 2>/dev/null || echo "0")
        if [ "$component_count" -gt 0 ]; then
            log "Successfully extracted $component_count components for $version"
            return 0
        else
            error "No components extracted for $version"
            return 1
        fi
    else
        error "Failed to extract configs for $version"
        return 1
    fi
}

# Clean up temporary files
cleanup() {
    log "Cleaning up..."
    rm -f "$SCRIPT_DIR"/configs_*.json
}

# Main execution
main() {
    log "Starting config extraction for locol..."
    
    setup_work_dir
    clone_repos
    
    local successful_versions=()
    
    for version in "${VERSIONS[@]}"; do
        if extract_version "$version"; then
            successful_versions+=("$version")
        fi
    done
    
    if [ ${#successful_versions[@]} -eq 0 ]; then
        error "No versions were successfully extracted"
        exit 1
    fi
    
    log "Successfully extracted ${#successful_versions[@]} versions: ${successful_versions[*]}"
    
    # Build database
    log "Building component database..."
    go run build_database.go --input="configs_*.json" --output="$OUTPUT_DIR/components.db"
    
    if [ $? -eq 0 ]; then
        log "Database created successfully at $OUTPUT_DIR/components.db"
        cleanup
    else
        error "Failed to build database"
        exit 1
    fi
    
    log "Config extraction complete!"
}

# Check dependencies
check_deps() {
    local missing_deps=()
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if ! command -v go &> /dev/null; then
        missing_deps+=("go")
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        error "Please install missing dependencies and try again"
        exit 1
    fi
    
    # Check Go version (need 1.19+)
    go_version=$(go version | cut -d' ' -f3 | sed 's/go//')
    if [[ "$(printf '%s\n' "1.19" "$go_version" | sort -V | head -n1)" != "1.19" ]]; then
        warn "Go 1.19+ recommended, you have $go_version"
    fi
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_deps
    main "$@"
fi
