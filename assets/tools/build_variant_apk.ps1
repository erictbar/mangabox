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

    # Find the generated unsigned APK
    $unsignedApkPath = Get-ChildItem -Path "android\app\build\outputs\apk\release" -Filter "*unsigned.apk" -Recurse | Select-Object -First 1

    if (-not $unsignedApkPath) {
        Write-Host "Error: Unsigned APK not found after build" -ForegroundColor Red
        exit 1
    }

    # Sign the APK
    Write-Host "Signing APK..." -ForegroundColor Yellow
    $variant = $NewAppId.Split('.')[-1]
    $outputName = "MangaBox-$variant-release.apk"
    
    # Check for Android SDK build-tools
    $buildToolsPath = Get-Content "android\local.properties" | Where-Object { $_ -match "sdk.dir" } | ForEach-Object { 
        $path = $_.Split('=')[1].Trim()
        # Remove escape characters and convert to proper Windows path
        $path = $path -replace '\\\\', '\'
        $path = $path -replace '\\:', ':'
        return $path
    }
    
    Write-Host "Using Android SDK at: $buildToolsPath" -ForegroundColor Yellow
    $buildToolsDir = Get-ChildItem -Path "$buildToolsPath\build-tools" | Where-Object { $_.PSIsContainer } | Sort-Object Name -Descending | Select-Object -First 1
    
    if (-not $buildToolsDir) {
        Write-Host "Error: Build-tools not found in Android SDK" -ForegroundColor Red
        exit 1
    }
    
    $zipalign = Join-Path $buildToolsDir.FullName "zipalign.exe"
    $apksigner = Join-Path $buildToolsDir.FullName "apksigner.bat"
    
    # Create debug keystore if it doesn't exist
    $debugKeystore = "$env:USERPROFILE\.android\debug.keystore"
    if (-not (Test-Path $debugKeystore)) {
        Write-Host "Creating debug keystore..." -ForegroundColor Yellow
        $androidDir = "$env:USERPROFILE\.android"
        if (-not (Test-Path $androidDir)) {
            New-Item -ItemType Directory -Path $androidDir -Force | Out-Null
        }
        
        # Find keytool in JDK
        $javaHome = $env:JAVA_HOME
        if (-not $javaHome) {
            # Try to find Java installation
            $javaExe = Get-Command java -ErrorAction SilentlyContinue
            if ($javaExe) {
                $javaHome = Split-Path (Split-Path $javaExe.Source -Parent) -Parent
            }
        }
        
        if (-not $javaHome -or -not (Test-Path "$javaHome\bin\keytool.exe")) {
            Write-Host "Warning: keytool not found. Attempting to use apksigner without custom keystore..." -ForegroundColor Yellow
            $debugKeystore = $null
        } else {
            $keytool = "$javaHome\bin\keytool.exe"
            $keytoolArgs = @(
                "-genkey",
                "-v",
                "-keystore", $debugKeystore,
                "-storepass", "android",
                "-alias", "androiddebugkey",
                "-keypass", "android",
                "-keyalg", "RSA",
                "-keysize", "2048",
                "-validity", "10000",
                "-dname", "CN=Android Debug,O=Android,C=US"
            )
            
            & $keytool @keytoolArgs 2>&1 | Out-Null
            Write-Host "Debug keystore created" -ForegroundColor Green
        }
    }
    
    # Align and sign the APK
    $alignedApk = "android\app\build\outputs\apk\release\app-release-aligned.apk"
    
    Write-Host "Aligning APK..." -ForegroundColor Yellow
    & $zipalign -v -p 4 $unsignedApkPath.FullName $alignedApk
    
    Write-Host "Signing APK..." -ForegroundColor Yellow
    if ($debugKeystore -and (Test-Path $debugKeystore)) {
        & $apksigner sign --ks $debugKeystore --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out $outputName $alignedApk
    } else {
        # Sign with apksigner's built-in debug signing
        Write-Host "Using apksigner debug signing..." -ForegroundColor Yellow
        & $apksigner sign --out $outputName $alignedApk
    }
    
    if (-not (Test-Path $outputName)) {
        Write-Host "Error: Signed APK not found" -ForegroundColor Red
        exit 1
    }

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
