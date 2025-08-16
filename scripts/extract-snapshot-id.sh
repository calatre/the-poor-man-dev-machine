#!/bin/bash

# Packer Post-Processor: Extract Hetzner Cloud Snapshot ID and Generate Manifest
# Bash equivalent of extract-snapshot-id.ps1

set -euo pipefail

# Parse command line arguments
ARTIFACT_ID=""
BUILD_NAME=""
BUILDER_TYPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --artifact-id)
            ARTIFACT_ID="$2"
            shift 2
            ;;
        --build-name)
            BUILD_NAME="$2"
            shift 2
            ;;
        --builder-type)
            BUILDER_TYPE="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$ARTIFACT_ID" ]]; then
    echo "Error: --artifact-id is required"
    echo "Usage: $0 --artifact-id <id> [--build-name <name>] [--builder-type <type>]"
    exit 1
fi

echo "========================================="
echo "Packer Post-Processor: Extracting Snapshot ID"
echo "========================================="
echo "ArtifactId: $ARTIFACT_ID"
echo "BuildName: $BUILD_NAME"
echo "BuilderType: $BUILDER_TYPE"

# Extract the snapshot ID from various possible formats
SNAPSHOT_ID=""

if [[ "$ARTIFACT_ID" =~ hcloud:snapshot:([0-9]+) ]]; then
    SNAPSHOT_ID="${BASH_REMATCH[1]}"
    echo "Matched format: hcloud:snapshot:ID"
elif [[ "$ARTIFACT_ID" =~ snapshot:([0-9]+) ]]; then
    SNAPSHOT_ID="${BASH_REMATCH[1]}"
    echo "Matched format: snapshot:ID"
elif [[ "$ARTIFACT_ID" =~ :([0-9]+)$ ]]; then
    SNAPSHOT_ID="${BASH_REMATCH[1]}"
    echo "Matched format: *:ID"
elif [[ "$ARTIFACT_ID" =~ ^([0-9]+)$ ]]; then
    SNAPSHOT_ID="${BASH_REMATCH[1]}"
    echo "Matched format: plain ID"
else
    # If no pattern matches, use the artifact ID as-is
    SNAPSHOT_ID="$ARTIFACT_ID"
    echo "No pattern matched, using ArtifactId as-is"
fi

echo "Extracted Snapshot ID: $SNAPSHOT_ID"

# Generate the Terraform/OpenTofu tfvars file
TFVARS_CONTENT="hcloud_image_id = \"$SNAPSHOT_ID\""
TFVARS_PATH="$(pwd)/image.auto.tfvars"

echo ""
echo "Writing to $TFVARS_PATH"
echo "$TFVARS_CONTENT" > "$TFVARS_PATH"
echo "✓ Created image.auto.tfvars"

# Get timestamps
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TIMESTAMP_UTC=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
TIMESTAMP_UNIX=$(date +%s)

# Get Packer version if available
PACKER_VERSION="unknown"
if command -v packer >/dev/null 2>&1; then
    PACKER_VERSION=$(packer version 2>/dev/null | grep -oE 'Packer v[0-9]+\.[0-9]+\.[0-9]+' | sed 's/Packer v//' || echo "unknown")
fi

# Get hostname and user
HOSTNAME=$(hostname 2>/dev/null || echo "unknown")
USER=$(whoami 2>/dev/null || echo "unknown")

# Generate a manifest file with build information
MANIFEST_PATH="$(pwd)/build-manifest.json"

echo ""
echo "Writing manifest to $MANIFEST_PATH"

# Create JSON manifest using jq if available, otherwise use basic formatting
if command -v jq >/dev/null 2>&1; then
    jq -n \
        --arg snapshot_id "$SNAPSHOT_ID" \
        --arg artifact_id "$ARTIFACT_ID" \
        --arg build_name "$BUILD_NAME" \
        --arg builder_type "$BUILDER_TYPE" \
        --arg timestamp "$TIMESTAMP" \
        --arg timestamp_utc "$TIMESTAMP_UTC" \
        --argjson timestamp_unix "$TIMESTAMP_UNIX" \
        --arg packer_version "$PACKER_VERSION" \
        --arg hostname "$HOSTNAME" \
        --arg user "$USER" \
        '{
            snapshot_id: $snapshot_id,
            artifact_id: $artifact_id,
            build_name: $build_name,
            builder_type: $builder_type,
            timestamp: $timestamp,
            timestamp_utc: $timestamp_utc,
            timestamp_unix: $timestamp_unix,
            packer_version: $packer_version,
            hostname: $hostname,
            user: $user
        }' > "$MANIFEST_PATH"
else
    # Fallback to basic JSON formatting without jq
    cat > "$MANIFEST_PATH" << EOF
{
    "snapshot_id": "$SNAPSHOT_ID",
    "artifact_id": "$ARTIFACT_ID",
    "build_name": "$BUILD_NAME",
    "builder_type": "$BUILDER_TYPE",
    "timestamp": "$TIMESTAMP",
    "timestamp_utc": "$TIMESTAMP_UTC",
    "timestamp_unix": $TIMESTAMP_UNIX,
    "packer_version": "$PACKER_VERSION",
    "hostname": "$HOSTNAME",
    "user": "$USER"
}
EOF
fi

echo "✓ Created build-manifest.json"

# Also append to a historical log file
HISTORY_PATH="$(pwd)/build-history.jsonl"

if command -v jq >/dev/null 2>&1; then
    jq -c \
        --arg snapshot_id "$SNAPSHOT_ID" \
        --arg artifact_id "$ARTIFACT_ID" \
        --arg build_name "$BUILD_NAME" \
        --arg builder_type "$BUILDER_TYPE" \
        --arg timestamp "$TIMESTAMP" \
        --arg timestamp_utc "$TIMESTAMP_UTC" \
        --argjson timestamp_unix "$TIMESTAMP_UNIX" \
        --arg packer_version "$PACKER_VERSION" \
        --arg hostname "$HOSTNAME" \
        --arg user "$USER" \
        '{
            snapshot_id: $snapshot_id,
            artifact_id: $artifact_id,
            build_name: $build_name,
            builder_type: $builder_type,
            timestamp: $timestamp,
            timestamp_utc: $timestamp_utc,
            timestamp_unix: $timestamp_unix,
            packer_version: $packer_version,
            hostname: $hostname,
            user: $user
        }' >> "$HISTORY_PATH"
else
    # Fallback without jq
    echo "{\"snapshot_id\":\"$SNAPSHOT_ID\",\"artifact_id\":\"$ARTIFACT_ID\",\"build_name\":\"$BUILD_NAME\",\"builder_type\":\"$BUILDER_TYPE\",\"timestamp\":\"$TIMESTAMP\",\"timestamp_utc\":\"$TIMESTAMP_UTC\",\"timestamp_unix\":$TIMESTAMP_UNIX,\"packer_version\":\"$PACKER_VERSION\",\"hostname\":\"$HOSTNAME\",\"user\":\"$USER\"}" >> "$HISTORY_PATH"
fi

echo "✓ Appended to build-history.jsonl"

echo ""
echo "========================================="
echo "Post-processing complete!"
echo "Snapshot ID: $SNAPSHOT_ID"
echo "========================================="
