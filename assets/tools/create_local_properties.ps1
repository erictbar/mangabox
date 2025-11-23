# Detect Android SDK and write android\local.properties
$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..') | Select-Object -ExpandProperty Path

# Candidate env vars / common locations
$candidates = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, "$env:LOCALAPPDATA\Android\Sdk", "C:\Android\Sdk", "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk")
$sdk = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $sdk) {
  Write-Error "Android SDK not found. Set ANDROID_SDK_ROOT or ANDROID_HOME or install the SDK."
  exit 1
}

# Ensure path uses double-backslashes for local.properties
$escaped = $sdk -replace '\\','\\'
$localPropsPath = Join-Path $repoRoot 'android\local.properties'
"sdk.dir=$escaped" | Out-File -FilePath $localPropsPath -Encoding ASCII -Force
Write-Output "Wrote local.properties -> $localPropsPath"