# Get current settings
$settings = Get-Content -Raw -Path $env:APPDATA\Docker\settings.json | ConvertFrom-Json

# Update settings
$settings.wslEngineEnabled = $true
$settings.exposeDockerAPIOnTCP2375 = $true

# Save updated settings
$settings | ConvertTo-Json -Depth 100 | Set-Content -Path $env:APPDATA\Docker\settings.json

$daemonPath = 'C:\ProgramData\Docker\config\daemon.json'

# Check if the file exists, if not create an empty JSON object
if (!(Test-Path -Path $daemonPath)) {
    $daemonSettings = @{}
} else {
    # Read the current settings
    $daemonSettings = Get-Content -Raw -Path $daemonPath | ConvertFrom-Json
}

# Update settings
$daemonSettings.experimental = $true
$daemonSettings.'metrics-addr' = 'localhost:9323'

# Save updated settings
$daemonSettings | ConvertTo-Json -Depth 100 | Set-Content -Path $daemonPath