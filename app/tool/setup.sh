#!/usr/bin/env bash
# The Log — one-shot Flutter setup (mobile + web).
# Scaffolds the native android/ios/web projects (version-matched to your
# Flutter), fetches deps, runs the sqflite web setup, and reminds you to add
# the runtime permissions.
set -e

cd "$(dirname "$0")/.."

echo "==> Scaffolding platform folders (android/ios/web) ..."
# Generates android/, ios/, web/ without touching lib/ or pubspec.yaml.
flutter create . --project-name the_log --platforms=android,ios,web

echo "==> Fetching packages ..."
flutter pub get

echo "==> Installing the web SQLite worker (sqflite on web -> IndexedDB) ..."
# Copies sqflite_sw.js + sqlite3.wasm into web/ so storage works in the browser.
dart run sqflite_common_ffi_web:setup

cat <<'NOTE'

================================================================
 RUN AS A WEB APP (open on your iPhone in Safari):
   flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
 Then on the iPhone (same wifi) open:  http://<YOUR-COMPUTER-LAN-IP>:8080
 Tap Share -> "Add to Home Screen" for an app-like PWA.

 RUN AS A NATIVE MOBILE APP:
   flutter run            # needs a connected device/emulator
   (iPhone native also needs a Mac + Xcode + signing.)

 ----------------------------------------------------------------
 NATIVE permissions (skip if you only run on web):

 ANDROID — android/app/src/main/AndroidManifest.xml (inside <manifest>):
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.CAMERA"/>
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

 iOS — ios/Runner/Info.plist (inside the top-level <dict>):
   <key>NSCameraUsageDescription</key>
   <string>Capture check-in photos to track progress.</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>Pick check-in photos to track progress.</string>
================================================================
NOTE
echo "Done."
