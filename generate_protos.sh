#!/bin/bash

# Create output directory
mkdir -p locol/Generated

# Set up paths
PROTO_ROOT="opentelemetry-proto"
PROTO_PATH="$PROTO_ROOT/opentelemetry/proto"
OUT_PATH="locol/Generated"

# Find all proto files recursively
find "$PROTO_PATH" -name "*.proto" | while read proto_file; do
    protoc --proto_path="$PROTO_ROOT" \
           --swift_opt=Visibility=Public \
           --swift_out="$OUT_PATH" \
           "$proto_file"
done

# Make generated files read-only to prevent accidental modification
if [ -n "$(ls -A $OUT_PATH)" ]; then
    chmod -R a-w "$OUT_PATH"
fi 
