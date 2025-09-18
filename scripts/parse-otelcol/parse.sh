#!/bin/bash

# Configuration
# Resolve script directory regardless of invocation path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is two levels up from this script (repo_root/scripts/parse-otelcol)
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Work directory lives alongside scripts to keep operations self-contained
WORK_DIR="$SCRIPT_DIR/../.work"
COLLECTOR_DIR="$WORK_DIR/opentelemetry-collector"
CONTRIB_DIR="$WORK_DIR/opentelemetry-collector-contrib"
# Default output directory is at project_root/satellite/Resources
OUTPUT_DIR="$ROOT_DIR/satellite/Resources"

# Flags / options (set by parse_args)
SINGLE_VERSION=""
KEEP_JSON=0
JSON_ONLY=0
OFFLINE=0

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

# Usage
usage() {
    cat >&2 <<EOF
Usage:
  $(basename "$0") [--version <tag>] [--json-only] [--keep-json] [--output-dir <dir>] [--offline]

Options:
  --version <tag>      Extract a single collector version (e.g., v0.95.0)
  --json-only          Only extract JSON; skip database build and cleanup
  --keep-json          Do not delete generated JSON files at the end
  --output-dir <dir>   Directory to place outputs (default: satellite/Resources)
  --offline            Do not clone/fetch; use local repos in .work
  -h, --help           Show this help

Examples:
  # Extract a single version and save JSON to satellite/Resources/
  $(basename "$0") --version v0.95.0 --json-only

  # Extract recent versions and build components.db
  $(basename "$0")
EOF
}

# Parse CLI args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                SINGLE_VERSION="$2"; shift 2 ;;
            --json-only)
                JSON_ONLY=1; KEEP_JSON=1; shift ;;
            --keep-json)
                KEEP_JSON=1; shift ;;
            --output-dir)
                OUTPUT_DIR="$2"; shift 2 ;;
            --offline)
                OFFLINE=1; shift ;;
            -h|--help)
                usage; exit 0 ;;
            *)
                error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done
}

# Get the latest release tag from GitHub API
get_latest_version() {
    log "Fetching latest collector version from GitHub..."
    local version
    # Use the releases endpoint, sorted by published date descending by default
    version=$(curl -s https://api.github.com/repos/open-telemetry/opentelemetry-collector/releases \
        | jq -r '.[0].tag_name')

    if [ -z "$version" ] || [ "$version" = "null" ]; then
        error "Failed to fetch latest version from GitHub API"
        error "Please check your internet connection and try again"
        exit 1
    fi

    echo "$version"
}

# Create work directory
setup_work_dir() {
    log "Setting up work directory..."
    mkdir -p "$WORK_DIR"
    mkdir -p "$OUTPUT_DIR"
}

# Clone or update repositories
clone_repos() {
    if [[ $OFFLINE -eq 1 ]]; then
        log "Offline mode: using local repositories in .work"
        if [ ! -d "$COLLECTOR_DIR" ] || [ ! -d "$CONTRIB_DIR" ]; then
            error "Offline mode requires existing repos at:"
            error "  $COLLECTOR_DIR and $CONTRIB_DIR"
            exit 1
        fi
        return
    fi

    log "Setting up repositories..."
    if [ ! -d "$COLLECTOR_DIR" ]; then
        log "Cloning opentelemetry-collector..."
        git clone https://github.com/open-telemetry/opentelemetry-collector.git "$COLLECTOR_DIR"
    else
        log "Updating opentelemetry-collector..."
        cd "$COLLECTOR_DIR" && git fetch --all --tags && cd - > /dev/null
    fi
    if [ ! -d "$CONTRIB_DIR" ]; then
        log "Cloning opentelemetry-collector-contrib..."
        git clone https://github.com/open-telemetry/opentelemetry-collector-contrib.git "$CONTRIB_DIR"
    else
        log "Updating opentelemetry-collector-contrib..."
        cd "$CONTRIB_DIR" && git fetch --all --tags && cd - > /dev/null
    fi
}

# Extract configs for a specific version
extract_version() {
    local version=$1
    log "Extracting configs for $version..."
    
    # Checkout collector version - exact match only
    cd "$COLLECTOR_DIR"
    if [[ $OFFLINE -ne 1 ]]; then
        git fetch --all --tags >/dev/null 2>&1
    fi
    
    if ! git checkout "$version" >/dev/null 2>&1; then
        error "Failed to checkout exact version $version in collector repository"
        cd - > /dev/null
        return 1
    fi
    
    local collector_commit=$(git rev-parse HEAD)
    log "Collector at commit: ${collector_commit:0:8}"
    
    # Checkout contrib version - exact match only
    cd "$CONTRIB_DIR"
    if [[ $OFFLINE -ne 1 ]]; then
        git fetch --all --tags >/dev/null 2>&1
    fi
    
    if ! git checkout "$version" >/dev/null 2>&1; then
        error "Failed to checkout exact version $version in contrib repository"
        cd - > /dev/null
        return 1
    fi
    
    local contrib_commit=$(git rev-parse HEAD)
    log "Contrib at commit: ${contrib_commit:0:8}"
    
    cd "$SCRIPT_DIR"
    
    # Run extraction
    local output_file
    # Always write JSON to the project output directory
    mkdir -p "$OUTPUT_DIR"
    output_file="$OUTPUT_DIR/configs_${version}.json"
    # Default to quiet extractor unless explicitly overridden by VERBOSE/DEBUG
    if [ "${VERBOSE:-0}" = "1" ] || [ "${DEBUG:-0}" = "1" ]; then
        LOCOL_DEBUG=1
    else
        LOCOL_DEBUG=0
    fi
    log "Running config extraction (LOCOL_DEBUG=${LOCOL_DEBUG})..."
    if [ "$LOCOL_DEBUG" = "1" ]; then
        >&2 echo "go run main.go --version=$version --collector-path=$COLLECTOR_DIR --contrib-path=$CONTRIB_DIR --output=$output_file"
    fi
    LOCOL_DEBUG="$LOCOL_DEBUG" go run main.go \
        --version="$version" \
        --collector-path="$COLLECTOR_DIR" \
        --contrib-path="$CONTRIB_DIR" \
        --output="$output_file"
    
    local extract_result=$?
    
    if [ $extract_result -eq 0 ]; then
        # Check if we actually got components
        local component_count=$(jq '.components | length' "$output_file" 2>/dev/null || echo "0")
        if [ "$component_count" -gt 0 ]; then
            log "Successfully extracted $component_count components for $version -> $output_file"
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
    if [[ $KEEP_JSON -eq 1 ]]; then
        log "Skipping cleanup (keeping JSON files)"
        return
    fi
    log "Cleaning up..."
    rm -f "$OUTPUT_DIR"/configs_*.json || true
}

# Main execution
main() {
    log "Starting config extraction for locol..."
    
    # Parse arguments and decide versions
    parse_args "$@"

    if [[ $OFFLINE -eq 1 && -z "$SINGLE_VERSION" ]]; then
        error "--offline requires --version <tag> (no GitHub API access)"
        exit 1
    fi

    setup_work_dir
    clone_repos
    
    # Decide which versions to extract
    local VERSIONS=()
    if [[ -n "$SINGLE_VERSION" ]]; then
        log "Will extract single version: $SINGLE_VERSION"
        VERSIONS=("$SINGLE_VERSION")
    else
        log "Getting latest collector version..."
        local latest
        latest=$(get_latest_version)
        VERSIONS=("$latest")
        log "Will extract latest version: ${VERSIONS[*]}"
    fi

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
    
    if [[ $JSON_ONLY -eq 1 ]]; then
        log "JSON-only mode; skipping database build."
        return 0
    fi

    # Ensure we're in the script directory for Go entry points
    cd "$SCRIPT_DIR"

    # Build database (multi-version workflow) if builder exists
    if [[ -f "$SCRIPT_DIR/build_database.go" ]]; then
        log "Building component database..."
        # JSON files are written to OUTPUT_DIR, so point input there
        go run build_database.go --input="$OUTPUT_DIR/configs_*.json" --output="$OUTPUT_DIR/components.db"
        if [ $? -eq 0 ]; then
            log "Database created successfully at $OUTPUT_DIR/components.db"
            cleanup
        else
            error "Failed to build database"
            exit 1
        fi
    else
        warn "No build_database.go found; skipping database build"
        # Do not cleanup JSON since they're the final output if no DB
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
    
    # curl needed only when fetching recent versions (no --version)
    if [[ -z "$SINGLE_VERSION" ]]; then
        if ! command -v curl &> /dev/null; then
            missing_deps+=("curl")
        fi
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
    # Parse args first so dependency checks can adapt
    parse_args "$@"
    check_deps
    main "$@"
fi
