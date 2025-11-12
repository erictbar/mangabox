#!/usr/bin/env bash
# Usage: rebuild_apk.sh [APK_FILE] [NEW_APPLICATION_ID] [NEW_APP_NAME]
# If no arguments provided, uses defaults for echamax variant
# Requires: apktool (in PATH), java, zipalign (optional), uber-apk-signer or apksigner/Android SDK
set -euo pipefail

# Default values for echamax variant
DEFAULT_APP_ID="com.EricBarbosa.MangaBox.echamax"
DEFAULT_APP_NAME="e MangaBox"

# Check if APK file is provided, otherwise look for it in common locations
if [ $# -eq 0 ]; then
  # Look for APK in artifact download location or current directory
  if [ -f "app-release.apk" ]; then
    APK="app-release.apk"
  elif [ -f "*.apk" ]; then
    APK=$(ls -1 *.apk | head -n1)
  else
    echo "No APK file found. Please provide APK file as first argument."
    exit 1
  fi
  NEW_APP_ID="$DEFAULT_APP_ID"
  NEW_APP_NAME="$DEFAULT_APP_NAME"
elif [ $# -eq 1 ]; then
  APK="$1"
  NEW_APP_ID="$DEFAULT_APP_ID"
  NEW_APP_NAME="$DEFAULT_APP_NAME"
elif [ $# -eq 3 ]; then
  APK="$1"
  NEW_APP_ID="$2"
  NEW_APP_NAME="$3"
else
  echo "Usage: $0 [APK_FILE] [NEW_APPLICATION_ID] [NEW_APP_NAME]"
  echo "  No args: Auto-detect APK and use defaults (com.EricBarbosa.MangaBox.echamax, 'e MangaBox')"
  echo "  1 arg: Use provided APK with defaults"
  echo "  3 args: Full control over APK, package ID, and app name"
  exit 1
fi

echo "Using APK: $APK"
echo "Target Package ID: $NEW_APP_ID"
echo "Target App Name: $NEW_APP_NAME"

WORKDIR=$(mktemp -d)
echo "Workdir: $WORKDIR"
cp "$APK" "$WORKDIR/original.apk"
cd "$WORKDIR"

# 1) Decode APK
echo "Decoding APK..."
apktool d -f original.apk -o decoded

# 2) Modify AndroidManifest.xml package and application label
MANIFEST=decoded/AndroidManifest.xml
if [ ! -f "$MANIFEST" ]; then
  echo "Manifest not found at $MANIFEST"
  exit 1
fi

# Change the package attribute at top of the manifest
# Note: This replaces the package="old.id" with new id.
# Be conservative: only replace the first occurrence.
old_package=$(grep -oP 'package="\K[^"]+' "$MANIFEST" | head -n1)
echo "Old package: $old_package"
if [ -z "$old_package" ]; then
  echo "Failed to find original package"
  exit 1
fi

# Replace package attribute
perl -0777 -pe "s/package=\"$old_package\"/package=\"$NEW_APP_ID\"/ if $.==1" -i "$MANIFEST" || true
# Also ensure provider authorities using old package are updated
perl -0777 -pe "s/${old_package}/${NEW_APP_ID}/g" -i "$MANIFEST" || true

# 3) Update res/values/strings.xml app_name if present
STRINGS=decoded/res/values/strings.xml
if [ -f "$STRINGS" ]; then
  if grep -q '<string name="app_name"' "$STRINGS"; then
    echo "Updating app_name in $STRINGS"
    perl -0777 -pe "s#<string name=\"app_name\">.*?</string>#<string name=\"app_name\">${NEW_APP_NAME}</string>#s" -i "$STRINGS" || true
  else
    echo "No app_name string. Adding one."
    # Insert app_name in resources
    perl -0777 -pe "s#</resources>#  <string name=\"app_name\">${NEW_APP_NAME}</string>\n</resources>#s" -i "$STRINGS"
  fi
else
  echo "No strings.xml found - creating one."
  mkdir -p decoded/res/values
  cat > decoded/res/values/strings.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <string name="app_name">${NEW_APP_NAME}</string>
</resources>
EOF
fi

# 4) (Optional) Replace launcher icons: place files in decoded/res/mipmap-* if you have them
# If you want to programmatically replace icons, copy them into decoded/res/mipmap-*/ic_launcher.png here.

# 5) Rebuild APK
echo "Rebuilding APK..."
apktool b decoded -o unsigned.apk

# 6) Align (optional) and sign
# Use uber-apk-signer if present; otherwise expect apksigner in PATH
SIGNED="rebuilt-signed.apk"
if [ -f "../uber-apk-signer/uber-apk-signer-*.jar" ] || [ -d ../uber-apk-signer ]; then
  echo "Signing with uber-apk-signer (if found)..."
  # Find jar
  UBER_JAR=$(ls -1 ../uber-apk-signer/*.jar 2>/dev/null | head -n1 || true)
  if [ -z "$UBER_JAR" ]; then
    echo "uber-apk-signer not found; falling back to jarsigner/apksigner not implemented."
    cp unsigned.apk "$SIGNED"
  else
    java -jar "$UBER_JAR" --apks unsigned.apk --output ./ --allowResign
    # Uber-apk-signer names output with -aligned-debugSigned.apk etc; pick the first signed apk
    found=$(ls *signed.apk 2>/dev/null | head -n1 || true)
    if [ -n "$found" ]; then
      mv "$found" "$SIGNED"
    else
      cp unsigned.apk "$SIGNED"
    fi
  fi
else
  echo "No uber-apk-signer available. Copying unsigned.apk to rebuilt-signed.apk (you must sign it manually)."
  cp unsigned.apk "$SIGNED"
fi

# Place output in repository root for action upload
OUTPUT_NAME="rebuilt-${NEW_APP_ID##*.}-signed.apk"
if [ -d "/github/workspace" ]; then
  mv "$SIGNED" "/github/workspace/$OUTPUT_NAME"
  echo "Built APK moved to /github/workspace/$OUTPUT_NAME"
elif [ -d "$PWD/../" ]; then
  cp "$SIGNED" "$PWD/../$OUTPUT_NAME"
  echo "Built APK copied to $PWD/../$OUTPUT_NAME"
else
  echo "Built APK available at: $WORKDIR/$SIGNED"
fi

echo "Output APK: $OUTPUT_NAME"
echo "Package ID: $NEW_APP_ID"
echo "App Name: $NEW_APP_NAME"

# Cleanup
# (Keep workdir for debugging if needed)
echo "Done. Workdir at $WORKDIR (not deleted for diagnostics)."