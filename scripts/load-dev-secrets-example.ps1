<#
Loads local secrets into environment variables for OpenTofu/Terraform and Packer.
This is an example template. Replace placeholder paths with your actual local paths.
#>

param(
  [string]$TokenPath = '<your-hetzner-token-path>',
  [string]$SshPublicKeyPath = '<your-ssh-key-path>'
)

# Hetzner token
if (Test-Path -LiteralPath $TokenPath) {
  try {
    $token = Get-Content -LiteralPath $TokenPath -Raw
  } catch {
    Write-Error "Failed to read token from ${TokenPath}: $_"
    exit 1
  }
  # Terraform/OpenTofu variable injection (main.tf uses var.hcloud_token)
  $env:TF_VAR_hcloud_token = $token
  # Provider-native env var (convenient for other tools)
  $env:HCLOUD_TOKEN = $token
  # Packer JSON template uses a user var named hcloud_token (legacy JSON uses PACKER_VAR_*)
  $env:PACKER_VAR_hcloud_token = $token
} else {
  Write-Error "Hetzner token file not found at $TokenPath"
}

# SSH public key path for Terraform
if (Test-Path -LiteralPath $SshPublicKeyPath) {
  $env:TF_VAR_ssh_public_key_path = $SshPublicKeyPath
} else {
  Write-Warning "SSH public key not found at $SshPublicKeyPath. Create it or pass -SshPublicKeyPath."
}

Write-Host "Environment configured. OpenTofu and Packer can now read necessary variables in this session."

