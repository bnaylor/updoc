#!/bin/bash
set -e

APP_NAME="updoc"
BUNDLE_ID="com.example.updoc"
BUILD_DIR=".build/apple/Products/Release"

# Build
swift build -c release --arch arm64 --arch x86_64

# Create structure
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# Copy binary
cp ".build/apple/Products/Release/${APP_NAME}" "${APP_NAME}.app/Contents/MacOS/"

# Copy Info.plist
cp src/updoc/Info.plist "${APP_NAME}.app/Contents/Info.plist"

# Code sign with entitlements (ad-hoc)
codesign --force --options runtime --entitlements src/updoc/entitlements.plist --sign - "${APP_NAME}.app"

echo "Bundle created: ${APP_NAME}.app"
