#!/bin/bash

# Exit on error
set -e

# Configuration
SCHEME_NAME="PReek"
PROJECT_PATH="PReek.xcodeproj"
EXPORT_OPTIONS_PLIST="./ExportOptions.plist"
AC_PASSWORD="personal"  # Keychain item name for notarytool credentials created via `notarytool store-credentials`

PRODUCT_NAME="PReek"
MARKETING_VERSION=$(xcodebuild -showBuildSettings -scheme "$SCHEME_NAME" -project "$PROJECT_PATH" -destination "platform=macOS,arch=arm64" 2>&1 | grep MARKETING_VERSION | awk '{print $3}')

# Create unique build directory
EXPORT_UUID=$(uuidgen)
BUILD_PATH="/tmp/$PRODUCT_NAME-build-$EXPORT_UUID"
ARCHIVE_PATH="$BUILD_PATH/$PRODUCT_NAME.xcarchive"
DMG_PATH="$BUILD_PATH/$PRODUCT_NAME-$MARKETING_VERSION.dmg"
LOGS_PATH="$BUILD_PATH/logs"

mkdir -p "$BUILD_PATH"
mkdir -p "$LOGS_PATH"

# Open the export folder
open "$BUILD_PATH"

echo "=== Starting Build Process ==="
echo "Detected version: $MARKETING_VERSION"
echo "Build directory: $BUILD_PATH"
echo "Archive path: $ARCHIVE_PATH"
echo "Logs directory: $LOGS_PATH"
echo ""

# Step 1: Create Archive
echo "=== Creating Archive ==="
xcodebuild archive \
  -scheme "$SCHEME_NAME" \
  -project "$PROJECT_PATH" \
  -destination "platform=macOS,arch=arm64" \
  -archivePath "$ARCHIVE_PATH" \
  -configuration Release \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  > "$LOGS_PATH/01-archive.log" 2>&1

if [ $? -ne 0 ]; then
  echo "Archive creation failed. Check log: $LOGS_PATH/01-archive.log"
  exit 1
fi

echo "Archive created successfully"
echo ""

# Step 2: Export Archive
echo "=== Exporting Archive ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$BUILD_PATH" \
  -allowProvisioningUpdates \
  > "$LOGS_PATH/02-export.log" 2>&1

if [ $? -ne 0 ]; then
  echo "Export of application archive failed. Check log: $LOGS_PATH/02-export.log"
  exit 1
fi

echo "Export completed successfully"
echo ""

# Step 3: Setup Node environment
echo "=== Setting up Node Environment ==="
fnm use v22 > "$LOGS_PATH/03-fnm.log" 2>&1

if [ $? -ne 0 ]; then
  echo "Failed to set Node version with fnm. Check log: $LOGS_PATH/03-fnm.log"
  exit 1
fi

echo "Node environment ready"
echo ""

# Step 4: Create DMG
echo "=== Creating DMG ==="

pushd "$BUILD_PATH" > /dev/null

npm install --global create-dmg > "$LOGS_PATH/04-npm-install.log" 2>&1

if [ $? -ne 0 ]; then
  echo "npm install failed. Check log: $LOGS_PATH/04-npm-install.log"
  exit 1
fi

create-dmg --no-version-in-filename "$PRODUCT_NAME.app" > "$LOGS_PATH/05-create-dmg.log" 2>&1

if [ $? -ne 0 ]; then
  echo "Creating DMG failed. Check log: $LOGS_PATH/05-create-dmg.log"
  exit 1
fi

# Rename DMG to expected name incl. version
mv "$PRODUCT_NAME.dmg" "$DMG_PATH"

popd > /dev/null

echo "DMG created successfully: $DMG_PATH"
echo ""

# Step 5: Submit for Notarization
echo "=== Submitting for Notarization ==="
xcrun notarytool submit \
  -p "$AC_PASSWORD" \
  --verbose \
  "$DMG_PATH" \
  --wait \
  --timeout 2h \
  --output-format plist > "$BUILD_PATH/NotarizationResponse.plist" 2> "$LOGS_PATH/06-notarization.log"

if [ $? -eq 0 ]; then
  message=$(/usr/libexec/PlistBuddy -c "Print :message" "$BUILD_PATH/NotarizationResponse.plist")
  status=$(/usr/libexec/PlistBuddy -c "Print :status" "$BUILD_PATH/NotarizationResponse.plist")
  echo "Notarization response: $message - $status"
else
  echo "Failed to submit DMG for notarization. Check log: $LOGS_PATH/06-notarization.log"
  exit 1
fi

echo "$message: $status"
echo ""

# Step 6: Staple Notarization Ticket
echo "=== Stapling Notarization Ticket ==="
xcrun stapler staple "$DMG_PATH" > "$LOGS_PATH/07-stapler.log" 2>&1

if [ $? -ne 0 ]; then
  echo "Failed stapling ticket to DMG. Check log: $LOGS_PATH/07-stapler.log"
  exit 1
fi

echo "Stapling completed successfully"
echo ""

# Success!
echo "=== Build Process Complete ==="
echo "Final DMG location: $DMG_PATH"
echo "Logs location: $LOGS_PATH"
