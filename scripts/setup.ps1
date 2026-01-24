# ============================================
# STREAMFLIX - Complete Setup Script
# ============================================
# This script sets up the entire StreamFlix project
# Usage: .\scripts\setup.ps1
# ============================================

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STREAMFLIX - Complete Setup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory and project root
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath
Set-Location $projectRoot

# Check if .env exists
$envFile = Join-Path $projectRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Host "ERROR: .env file not found!" -ForegroundColor Red
    Write-Host "Please create .env from .env.example:" -ForegroundColor Yellow
    Write-Host "  cp .env.example .env" -ForegroundColor Cyan
    Write-Host "Then fill in your credentials." -ForegroundColor Yellow
    exit 1
}

# Load environment variables
Write-Host "1. Loading environment variables..." -ForegroundColor Green
. "$scriptPath\load-env.ps1"

# Check required variables
Write-Host ""
Write-Host "2. Checking required environment variables..." -ForegroundColor Green

$requiredVars = @(
    "SECRET_KEY_BASE",
    "GUARDIAN_SECRET_KEY",
    "DB_HOSTNAME",
    "DB_PASSWORD"
)

$missing = @()
foreach ($var in $requiredVars) {
    $value = [Environment]::GetEnvironmentVariable($var)
    if ([string]::IsNullOrEmpty($value) -or $value -like "*GENERATE*" -or $value -like "*REPLACE*") {
        $missing += $var
    }
}

if ($missing.Count -gt 0) {
    Write-Host "ERROR: The following required variables are missing or not configured:" -ForegroundColor Red
    foreach ($var in $missing) {
        Write-Host "  - $var" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Run .\scripts\generate-secrets.ps1 to generate secret keys" -ForegroundColor Cyan
    exit 1
}

Write-Host "  All required variables are set!" -ForegroundColor DarkGray

# Install dependencies
Write-Host ""
Write-Host "3. Installing Elixir dependencies..." -ForegroundColor Green
mix deps.get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get dependencies" -ForegroundColor Red
    exit 1
}

# Compile
Write-Host ""
Write-Host "4. Compiling project..." -ForegroundColor Green
mix compile
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Compilation failed" -ForegroundColor Red
    exit 1
}

# Run migrations
Write-Host ""
Write-Host "5. Running database migrations..." -ForegroundColor Green
Write-Host "   WARNING: This will clean existing tables in the database!" -ForegroundColor Yellow
$confirm = Read-Host "   Continue? (y/n)"
if ($confirm -ne "y") {
    Write-Host "Aborted by user" -ForegroundColor Yellow
    exit 0
}

mix ecto.migrate
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Migrations failed" -ForegroundColor Red
    Write-Host "Try running: mix ecto.create first if database doesn't exist" -ForegroundColor Yellow
    exit 1
}

# Run seeds
Write-Host ""
Write-Host "6. Running database seeds..." -ForegroundColor Green
mix run apps/streamflix_core/priv/repo/seeds.exs
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Seeds may have failed (this is ok if data already exists)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " SETUP COMPLETE!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "To start the server:" -ForegroundColor Yellow
Write-Host "  . .\scripts\load-env.ps1" -ForegroundColor Cyan
Write-Host "  mix phx.server" -ForegroundColor Cyan
Write-Host ""
Write-Host "Then visit: http://localhost:4000" -ForegroundColor Yellow
