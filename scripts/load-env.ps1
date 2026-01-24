# ============================================
# STREAMFLIX - Load Environment Variables
# ============================================
# Run this script in PowerShell before starting the application
# Usage: . .\scripts\load-env.ps1
# ============================================

param(
    [string]$EnvFile = ".env"
)

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
$envFilePath = Join-Path $projectRoot $EnvFile

if (-not (Test-Path $envFilePath)) {
    Write-Host "ERROR: .env file not found at $envFilePath" -ForegroundColor Red
    Write-Host "Please copy .env.example to .env and fill in your values" -ForegroundColor Yellow
    Write-Host "  cp .env.example .env" -ForegroundColor Cyan
    exit 1
}

Write-Host "Loading environment variables from $envFilePath..." -ForegroundColor Green

Get-Content $envFilePath | ForEach-Object {
    # Skip empty lines and comments
    if ($_ -match '^\s*$' -or $_ -match '^\s*#') {
        return
    }
    
    # Parse key=value
    if ($_ -match '^([^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        
        # Remove quotes if present
        if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
            $value = $matches[1]
        }
        
        # Set environment variable
        [Environment]::SetEnvironmentVariable($key, $value, "Process")
        Write-Host "  Set: $key" -ForegroundColor DarkGray
    }
}

Write-Host "Environment variables loaded successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now run:" -ForegroundColor Yellow
Write-Host "  mix phx.server" -ForegroundColor Cyan
