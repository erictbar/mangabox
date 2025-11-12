#!/usr/bin/env bash
# Build Android APK with custom package ID and app name
# Usage: build_variant_apk.sh [NEW_APPLICATION_ID] [NEW_APP_NAME]
set -euo pipefail

# Default values for echamax variant
NEW_APP_ID="${1:-com.EricBarbosa.MangaBox.echamax}"
NEW_APP_NAME="${2:-e MangaBox}"

echo "Building Android APK variant"
echo "Package ID: $NEW_APP_ID"
echo "App Name: $NEW_APP_NAME"

# Check if we're in the project root
if [ ! -f "package.json" ]; then
  echo "Error: package.json not found. Please run this script from the project root."
  exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi

# Save original files for restoration
ORIGINAL_CAPACITOR_CONFIG="capacitor.config.json"
BACKUP_CAPACITOR_CONFIG="capacitor.config.json.backup"

# Backup original config
echo "Backing up original capacitor.config.json..."
cp "$ORIGINAL_CAPACITOR_CONFIG" "$BACKUP_CAPACITOR_CONFIG"

# Function to restore original config on exit
cleanup() {
  echo "Restoring original capacitor.config.json..."
  mv "$BACKUP_CAPACITOR_CONFIG" "$ORIGINAL_CAPACITOR_CONFIG"
}
trap cleanup EXIT

# Modify capacitor.config.json
echo "Modifying capacitor.config.json..."
node -e "
const fs = require('fs');
const config = JSON.parse(fs.readFileSync('$ORIGINAL_CAPACITOR_CONFIG', 'utf8'));
config.appId = '$NEW_APP_ID';
config.appName = '$NEW_APP_NAME';
fs.writeFileSync('$ORIGINAL_CAPACITOR_CONFIG', JSON.stringify(config, null, '\t'));
console.log('Updated capacitor.config.json');
"

# Check if android folder exists
if [ ! -d "android" ]; then
  echo "Android platform not found. Adding Android platform..."
  npx @capacitor/cli add android
else
  echo "Syncing with existing Android platform..."
  npx @capacitor/cli sync android
fi

# Navigate to android folder and build
echo "Building Android APK..."
cd android
./gradlew assembleRelease

# Find the generated APK
APK_PATH=$(find app/build/outputs/apk/release -name "*.apk" | head -n1)

if [ -z "$APK_PATH" ]; then
  echo "Error: APK not found after build"
  exit 1
fi

# Copy APK to root directory with descriptive name
OUTPUT_NAME="MangaBox-${NEW_APP_ID##*.}-release.apk"
cp "$APK_PATH" "../$OUTPUT_NAME"

echo ""
echo "✓ Build successful!"
echo "APK created: $OUTPUT_NAME"
echo "Package ID: $NEW_APP_ID"
echo "App Name: $NEW_APP_NAME"
