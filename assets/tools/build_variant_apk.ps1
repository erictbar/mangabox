# Build Android APK with custom package ID and app name
# Usage: .\build_variant_apk.ps1 [NEW_APPLICATION_ID] [NEW_APP_NAME]

param(
    [string]$NewAppId = "com.EricBarbosa.MangaBox.echamax",
    [string]$NewAppName = "e MangaBox"
)

Write-Host "Building Android APK variant" -ForegroundColor Green
Write-Host "Package ID: $NewAppId"
Write-Host "App Name: $NewAppName"

# Check if we're in the project root
if (-not (Test-Path "package.json")) {
    Write-Host "Error: package.json not found. Please run this script from the project root." -ForegroundColor Red
    exit 1
}

# Install dependencies if node_modules doesn't exist
if (-not (Test-Path "node_modules")) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    npm install
}

# Prepare dist/mangabox directory with web assets
if (-not (Test-Path "dist\mangabox")) {
    Write-Host "Creating dist/mangabox directory with web assets..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path "dist\mangabox" -Force | Out-Null
    
    # Copy web assets
    Copy-Item -Path "index.html" -Destination "dist\mangabox\" -Force
    Copy-Item -Path "*.css" -Destination "dist\mangabox\" -Force
    Copy-Item -Path "*.js" -Destination "dist\mangabox\" -Force
    Copy-Item -Path "manifest.json" -Destination "dist\mangabox\" -Force
    Copy-Item -Path "fontawesome" -Destination "dist\mangabox\fontawesome" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "webfonts" -Destination "dist\mangabox\webfonts" -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "*.png" -Destination "dist\mangabox\" -Force -ErrorAction SilentlyContinue
    Copy-Item -Path "*.svg" -Destination "dist\mangabox\" -Force -ErrorAction SilentlyContinue
    
    Write-Host "Web assets copied to dist/mangabox" -ForegroundColor Green
}

# Backup original config
$originalConfig = "capacitor.config.json"
$backupConfig = "capacitor.config.json.backup"

Write-Host "Backing up original capacitor.config.json..." -ForegroundColor Yellow
Copy-Item $originalConfig $backupConfig -Force

try {
    # Modify capacitor.config.json
    Write-Host "Modifying capacitor.config.json..." -ForegroundColor Yellow
    $config = Get-Content $originalConfig -Raw | ConvertFrom-Json
    $config.appId = $NewAppId
    $config.appName = $NewAppName
    $config | ConvertTo-Json -Depth 10 | Set-Content $originalConfig
    Write-Host "Updated capacitor.config.json" -ForegroundColor Green

    # Check if android folder exists
    if (-not (Test-Path "android")) {
        Write-Host "Android platform not found. Adding Android platform..." -ForegroundColor Yellow
        npx @capacitor/cli add android
    } else {
        Write-Host "Syncing with existing Android platform..." -ForegroundColor Yellow
        npx @capacitor/cli sync android
    }

    # Navigate to android folder and build
    Write-Host "Building Android APK..." -ForegroundColor Yellow
    Push-Location android
    .\gradlew.bat assembleRelease
    Pop-Location

    # Find the generated APK
    $apkPath = Get-ChildItem -Path "android\app\build\outputs\apk\release" -Filter "*.apk" -Recurse | Select-Object -First 1

    if (-not $apkPath) {
        Write-Host "Error: APK not found after build" -ForegroundColor Red
        exit 1
    }

    # Copy APK to root directory with descriptive name
    $variant = $NewAppId.Split('.')[-1]
    $outputName = "MangaBox-$variant-release.apk"
    Copy-Item $apkPath.FullName $outputName -Force

    Write-Host ""
    Write-Host "✓ Build successful!" -ForegroundColor Green
    Write-Host "APK created: $outputName" -ForegroundColor Cyan
    Write-Host "Package ID: $NewAppId" -ForegroundColor Cyan
    Write-Host "App Name: $NewAppName" -ForegroundColor Cyan

} finally {
    # Restore original config
    Write-Host "Restoring original capacitor.config.json..." -ForegroundColor Yellow
    Move-Item $backupConfig $originalConfig -Force
}
