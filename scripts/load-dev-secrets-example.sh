#!/usr/bin/env bash
# Loads local secrets into environment variables for OpenTofu/Terraform and Packer.
# This is an example template. Replace placeholder paths with your actual local paths.
# Usage: source ./load-dev-secrets-example.sh [token_path] [ssh_pub_key_path]

set -euo pipefail

TOKEN_PATH="${1:-<your-hetzner-token-path>}"
SSH_PUB_KEY_PATH="${2:-<your-ssh-key-path>}"

# Hetzner token
if [ -f "$TOKEN_PATH" ]; then
  if ! HCLOUD_TOKEN_CONTENT=$(cat "$TOKEN_PATH"); then
    echo "Failed to read token from $TOKEN_PATH" >&2
    return 1 2>/dev/null || exit 1
  fi
  # Terraform/OpenTofu variable injection (main.tf uses var.hcloud_token)
  export TF_VAR_hcloud_token="$HCLOUD_TOKEN_CONTENT"
  # Provider-native env var (convenient for other tools)
  export HCLOUD_TOKEN="$HCLOUD_TOKEN_CONTENT"
  # Packer JSON template uses a user var named hcloud_token (legacy JSON uses PACKER_VAR_*)
  export PACKER_VAR_hcloud_token="$HCLOUD_TOKEN_CONTENT"
else
  echo "Hetzner token file not found at $TOKEN_PATH" >&2
fi

# SSH public key path for Terraform
if [ -f "$SSH_PUB_KEY_PATH" ]; then
  export TF_VAR_ssh_public_key_path="$SSH_PUB_KEY_PATH"
else
  echo "SSH public key not found at $SSH_PUB_KEY_PATH. Create it or pass as arg." >&2
fi

echo "Environment configured. OpenTofu and Packer can now read necessary variables in this shell."

