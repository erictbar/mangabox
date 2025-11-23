# Build Android APK with custom package ID and app name
# Usage: .\build_variant_apk.ps1 [NEW_APPLICATION_ID] [NEW_APP_NAME]

param(
    [string]$NewAppId = "com.EricBarbosa.MangaBox.echamax",
    [string]$NewAppName = "e MangaBox"
)

# Define all variants to build
$variants = @(
    @{
        AppId = "com.EricBarbosa.MangaBox.echamax"
        AppName = "e MangaBox"
        OutputSuffix = "echamax"
    },
    @{
        AppId = "com.EricBarbosa.MangaBox.fork"
        AppName = "f MangaBox"
        OutputSuffix = "fork"
    }
)

Write-Host "Building Android APK variants" -ForegroundColor Green
Write-Host "Will build $($variants.Count) variant(s)" -ForegroundColor Cyan
Write-Host ""

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

# Install additional Capacitor plugins for Android if not already installed
Write-Host "Installing Capacitor plugins..." -ForegroundColor Yellow
npm install @capacitor/status-bar@7 --save 2>&1 | Out-Null
npm install @capacitor/camera@7 --save 2>&1 | Out-Null
npm install @capacitor/filesystem@7 --save 2>&1 | Out-Null
npm install @capawesome/capacitor-file-picker@7 --save 2>&1 | Out-Null
npm install @capawesome/capacitor-android-edge-to-edge-support --save 2>&1 | Out-Null
npm install @ethion/capacitor-navigation-bar --save 2>&1 | Out-Null
Write-Host "Capacitor plugins installed" -ForegroundColor Green

# Prepare dist/mangabox directory with web assets
Write-Host "Preparing dist/mangabox directory with web assets..." -ForegroundColor Yellow
if (-not (Test-Path "dist\mangabox")) {
    New-Item -ItemType Directory -Path "dist\mangabox" -Force | Out-Null
}

# Copy web assets (always refresh to ensure latest versions)
Copy-Item -Path "index.html" -Destination "dist\mangabox\" -Force
Copy-Item -Path "*.css" -Destination "dist\mangabox\" -Force
Copy-Item -Path "*.js" -Destination "dist\mangabox\" -Force
Copy-Item -Path "manifest.json" -Destination "dist\mangabox\" -Force
Copy-Item -Path "fontawesome" -Destination "dist\mangabox\fontawesome" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "webfonts" -Destination "dist\mangabox\webfonts" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "*.png" -Destination "dist\mangabox\" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "*.svg" -Destination "dist\mangabox\" -Force -ErrorAction SilentlyContinue
Copy-Item -Path "library-thumbnails" -Destination "dist\mangabox\library-thumbnails" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "library-letters" -Destination "dist\mangabox\library-letters" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "flags" -Destination "dist\mangabox\flags" -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -Path "logo" -Destination "dist\mangabox\logo" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Web assets copied to dist/mangabox" -ForegroundColor Green


# Backup original config
$originalConfig = "capacitor.config.json"
$backupConfig = "capacitor.config.json.backup"
$buildGradlePath = "android\app\build.gradle"
$buildGradleBackup = "build.gradle.backup"
$stringsXmlPath = "android\app\src\main\res\values\strings.xml"
$stringsXmlBackup = "strings.xml.backup"

Write-Host "Backing up original configuration files..." -ForegroundColor Yellow
Copy-Item $originalConfig $backupConfig -Force

# Backup Android files to root directory (not inside android folder)
if (Test-Path $buildGradlePath) {
    Copy-Item $buildGradlePath $buildGradleBackup -Force
}
if (Test-Path $stringsXmlPath) {
    Copy-Item $stringsXmlPath $stringsXmlBackup -Force
}

try {
    # Build each variant
    foreach ($variant in $variants) {
        $NewAppId = $variant.AppId
        $NewAppName = $variant.AppName
        $outputSuffix = $variant.OutputSuffix
        
        Write-Host ""
        Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Building variant: $NewAppName" -ForegroundColor Cyan
    Write-Host "Package ID: $NewAppId" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Restore original Android config files before each variant
    if (Test-Path $buildGradleBackup) {
        Copy-Item $buildGradleBackup $buildGradlePath -Force
        Write-Host "Restored original build.gradle" -ForegroundColor Yellow
    }
    if (Test-Path $stringsXmlBackup) {
        Copy-Item $stringsXmlBackup $stringsXmlPath -Force
        Write-Host "Restored original strings.xml" -ForegroundColor Yellow
    }
    
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

    # Update Android build.gradle with the correct package ID
    Write-Host "Updating Android build.gradle..." -ForegroundColor Yellow
    $buildGradlePath = "android\app\build.gradle"
    $buildGradleContent = Get-Content $buildGradlePath -Raw
    
    # Update namespace and applicationId
    $buildGradleContent = $buildGradleContent -replace 'namespace\s+"[^"]+"', "namespace `"$NewAppId`""
    $buildGradleContent = $buildGradleContent -replace 'applicationId\s+"[^"]+"', "applicationId `"$NewAppId`""
    
    Set-Content $buildGradlePath $buildGradleContent
    Write-Host "Updated build.gradle with package ID: $NewAppId" -ForegroundColor Green

    # Update Android strings.xml with the correct app name
    Write-Host "Updating Android strings.xml..." -ForegroundColor Yellow
    $stringsXmlPath = "android\app\src\main\res\values\strings.xml"
    $stringsXmlContent = Get-Content $stringsXmlPath -Raw
    
    # Update app_name and title_activity_main
    $stringsXmlContent = $stringsXmlContent -replace '<string name="app_name">[^<]*</string>', "<string name=`"app_name`">$NewAppName</string>"
    $stringsXmlContent = $stringsXmlContent -replace '<string name="title_activity_main">[^<]*</string>', "<string name=`"title_activity_main`">$NewAppName</string>"
    $stringsXmlContent = $stringsXmlContent -replace '<string name="package_name">[^<]*</string>', "<string name=`"package_name`">$NewAppId</string>"
    
    Set-Content $stringsXmlPath $stringsXmlContent
    Write-Host "Updated strings.xml with app name: $NewAppName" -ForegroundColor Green

    # Update MainActivity.java package name and location
    Write-Host "Updating MainActivity.java package..." -ForegroundColor Yellow
    
    # Find existing MainActivity.java
    $mainActivityPath = Get-ChildItem -Path "android\app\src\main\java" -Filter "MainActivity.java" -Recurse | Select-Object -First 1
    
    if ($mainActivityPath) {
        # Read and update package declaration
        $mainActivityContent = Get-Content $mainActivityPath.FullName -Raw
        $mainActivityContent = $mainActivityContent -replace 'package\s+[^;]+;', "package $NewAppId;"
        
        # Create new package directory structure
        $packagePath = $NewAppId -replace '\.', '\'
        $newMainActivityDir = "android\app\src\main\java\$packagePath"
        New-Item -ItemType Directory -Path $newMainActivityDir -Force | Out-Null
        
        # Write MainActivity.java to new location
        $newMainActivityPath = Join-Path $newMainActivityDir "MainActivity.java"
        Set-Content $newMainActivityPath $mainActivityContent
        
        Write-Host "Updated MainActivity.java with package: $NewAppId" -ForegroundColor Green
    } else {
        Write-Host "Warning: MainActivity.java not found" -ForegroundColor Red
    }

    # Create local.properties with Android SDK path
    Write-Host "Configuring Android SDK location..." -ForegroundColor Yellow
    $localPropsPath = "android\local.properties"
    
    # Try to find Android SDK
    $sdkPath = $null
    $candidates = @(
        $env:ANDROID_SDK_ROOT,
        $env:ANDROID_HOME,
        "D:\Apps\AndroidStudio",
        "$env:LOCALAPPDATA\Android\Sdk",
        "C:\Android\Sdk",
        "$env:USERPROFILE\AppData\Local\Android\Sdk"
    )
    
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            $sdkPath = $candidate
            break
        }
    }
    
    if (-not $sdkPath) {
        Write-Host "Error: Android SDK not found. Please set ANDROID_SDK_ROOT or ANDROID_HOME environment variable." -ForegroundColor Red
        Write-Host "Common SDK locations:" -ForegroundColor Yellow
        Write-Host "  - %LOCALAPPDATA%\Android\Sdk" -ForegroundColor Yellow
        Write-Host "  - C:\Android\Sdk" -ForegroundColor Yellow
        Write-Host "  - %USERPROFILE%\AppData\Local\Android\Sdk" -ForegroundColor Yellow
        exit 1
    }
    
    # Write local.properties with escaped backslashes
    $escapedSdkPath = $sdkPath -replace '\\', '\\'
    "sdk.dir=$escapedSdkPath" | Out-File -FilePath $localPropsPath -Encoding ASCII -Force
    Write-Host "SDK location configured: $sdkPath" -ForegroundColor Green
    
    # Navigate to android folder and build
    Write-Host "Cleaning previous build artifacts..." -ForegroundColor Yellow
    
    Push-Location android
    
    # Use Gradle clean which handles file locks properly
    .\gradlew.bat clean --quiet
    
    Write-Host "Building Android APK..." -ForegroundColor Yellow
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
    $outputName = "MangaBox-$outputSuffix-release.apk"
    
    
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
        Write-Host "Error: Signed APK not found for $NewAppName" -ForegroundColor Red
        continue
    }

    Write-Host ""
    Write-Host "✓ Variant build successful!" -ForegroundColor Green
    Write-Host "APK created: $outputName" -ForegroundColor Cyan
    Write-Host ""
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✓ All variants built successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    # List all created APKs
    Write-Host "Created APKs:" -ForegroundColor Cyan
    foreach ($variant in $variants) {
        $apkName = "MangaBox-$($variant.OutputSuffix)-release.apk"
        if (Test-Path $apkName) {
            $size = (Get-Item $apkName).Length / 1MB
            Write-Host "  - $apkName ($([math]::Round($size, 2)) MB)" -ForegroundColor White
        }
    }

} finally {
    # Restore original config files
    Write-Host "Restoring original configuration files..." -ForegroundColor Yellow
    if (Test-Path $backupConfig) {
        Move-Item $backupConfig $originalConfig -Force
    }
    if (Test-Path $buildGradleBackup) {
        Move-Item $buildGradleBackup $buildGradlePath -Force
    }
    if (Test-Path $stringsXmlBackup) {
        Move-Item $stringsXmlBackup $stringsXmlPath -Force
    }
}
