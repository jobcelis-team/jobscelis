# ============================================
# STREAMFLIX - Generate Secret Keys
# ============================================
# This script generates secure random keys for your .env file
# Usage: .\scripts\generate-secrets.ps1
# ============================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " STREAMFLIX - Secret Key Generator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Function to generate a random base64 string
function Generate-SecretKey {
    param([int]$Length = 64)
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($bytes)
    return [Convert]::ToBase64String($bytes)
}

# Generate keys
$secretKeyBase = Generate-SecretKey -Length 64
$guardianSecret = Generate-SecretKey -Length 64
$liveViewSalt = Generate-SecretKey -Length 32
$nodeCookie = Generate-SecretKey -Length 32

Write-Host "Copy these values to your .env file:" -ForegroundColor Green
Write-Host ""
Write-Host "SECRET_KEY_BASE=$secretKeyBase" -ForegroundColor Yellow
Write-Host ""
Write-Host "GUARDIAN_SECRET_KEY=$guardianSecret" -ForegroundColor Yellow
Write-Host ""
Write-Host "LIVE_VIEW_SIGNING_SALT=$liveViewSalt" -ForegroundColor Yellow
Write-Host ""
Write-Host "NODE_COOKIE=$nodeCookie" -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "IMPORTANT: Keep these keys secret!" -ForegroundColor Red
Write-Host "Never commit them to version control!" -ForegroundColor Red
Write-Host "============================================" -ForegroundColor Cyan
