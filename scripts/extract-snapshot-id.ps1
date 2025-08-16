param(
    [Parameter(Mandatory=$true)]
    [string]$ArtifactId,
    
    [Parameter(Mandatory=$false)]
    [string]$BuildName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$BuilderType = ""
)

Write-Host "========================================="
Write-Host "Packer Post-Processor: Extracting Snapshot ID"
Write-Host "========================================="
Write-Host "ArtifactId: $ArtifactId"
Write-Host "BuildName: $BuildName"
Write-Host "BuilderType: $BuilderType"

# Extract the snapshot ID from various possible formats
$snapshotId = ""

if ($ArtifactId -match 'hcloud:snapshot:([0-9]+)') {
    $snapshotId = $matches[1]
    Write-Host "Matched format: hcloud:snapshot:ID"
} elseif ($ArtifactId -match 'snapshot:([0-9]+)') {
    $snapshotId = $matches[1]
    Write-Host "Matched format: snapshot:ID"
} elseif ($ArtifactId -match ':([0-9]+)$') {
    $snapshotId = $matches[1]
    Write-Host "Matched format: *:ID"
} elseif ($ArtifactId -match '^([0-9]+)$') {
    $snapshotId = $matches[1]
    Write-Host "Matched format: plain ID"
} else {
    # If no pattern matches, use the artifact ID as-is
    $snapshotId = $ArtifactId
    Write-Host "No pattern matched, using ArtifactId as-is"
}

Write-Host "Extracted Snapshot ID: $snapshotId"

# Generate the Terraform/OpenTofu tfvars file
$tfvarsContent = "hcloud_snapshot_id = `"$snapshotId`""
$tfvarsPath = Join-Path (Get-Location) "snapshot.auto.tfvars"

Write-Host ""
Write-Host "Writing to $tfvarsPath"
Set-Content -Path $tfvarsPath -Value $tfvarsContent -Encoding ascii
Write-Host "Created snapshot.auto.tfvars"

# Generate a manifest file with build information
$manifest = @{
    snapshot_id = $snapshotId
    artifact_id = $ArtifactId
    build_name = $BuildName
    builder_type = $BuilderType
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
    timestamp_unix = [int][double]::Parse((Get-Date -UFormat %s))
    packer_version = if (Get-Command packer -ErrorAction SilentlyContinue) { 
        (packer version | Select-String -Pattern "Packer v(.+)" | ForEach-Object { $_.Matches.Groups[1].Value })
    } else { 
        "unknown" 
    }
    hostname = $env:COMPUTERNAME
    user = $env:USERNAME
}

# Convert to JSON and save
$manifestJson = $manifest | ConvertTo-Json -Depth 10
$manifestPath = Join-Path (Get-Location) "build-manifest.json"

Write-Host ""
Write-Host "Writing manifest to $manifestPath"
Set-Content -Path $manifestPath -Value $manifestJson -Encoding utf8
Write-Host "Created build-manifest.json"

# Also append to a historical log file
$historyPath = Join-Path (Get-Location) "build-history.jsonl"
$historyEntry = $manifest | ConvertTo-Json -Compress
Add-Content -Path $historyPath -Value $historyEntry -Encoding utf8
Write-Host "Appended to build-history.jsonl"

Write-Host ""
Write-Host "========================================="
Write-Host "Post-processing complete!"
Write-Host "Snapshot ID: $snapshotId"
Write-Host "========================================="
