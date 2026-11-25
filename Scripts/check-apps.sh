#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CACHE="${TMPDIR:-/tmp}/syncalarm-modules"
mkdir -p "$CACHE"
for platform in iphoneos watchos; do
  if [ "$platform" = iphoneos ]; then
    target=arm64-apple-ios17.0
    directory=SyncAlarm
  else
    target=arm64_32-apple-watchos10.0
    directory='SyncAlarmWatch Watch App'
  fi
  sdk=$(xcrun --sdk "$platform" --show-sdk-path)
  # One shared connectivity implementation is selected per app.
  sources=(Shared/*.swift "$directory"/*.swift)
  xcrun swiftc -typecheck -swift-version 5 -module-cache-path "$CACHE/$platform" -sdk "$sdk" -target "$target" "${sources[@]}"
done

sdk=$(xcrun --sdk iphoneos --show-sdk-path)
xcrun swiftc -typecheck -swift-version 5 -module-cache-path "$CACHE/iphoneos" -sdk "$sdk" -target arm64-apple-ios26.0 -application-extension Shared/AlarmKitPresentation.swift SyncAlarmWidgets/*.swift
