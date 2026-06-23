#!/usr/bin/env bash
# The Log — one-shot Flutter setup.
# Scaffolds the native android/ios projects (version-matched to your Flutter),
# fetches deps, and reminds you to add the runtime permissions.
set -e

cd "$(dirname "$0")/.."

echo "==> Scaffolding native platform folders (android/ios) ..."
# Generates android/ & ios/ without touching lib/ or pubspec.yaml.
flutter create . --project-name the_log --platforms=android,ios

echo "==> Fetching packages ..."
flutter pub get

cat <<'NOTE'

================================================================
 Add runtime permissions, then `flutter run`:

 ANDROID — android/app/src/main/AndroidManifest.xml
   Add inside <manifest> (above <application>):
     <uses-permission android:name="android.permission.INTERNET"/>
     <uses-permission android:name="android.permission.CAMERA"/>
     <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
     <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

 iOS — ios/Runner/Info.plist
   Add inside the top-level <dict>:
     <key>NSCameraUsageDescription</key>
     <string>Capture check-in photos to track progress.</string>
     <key>NSPhotoLibraryUsageDescription</key>
     <string>Pick check-in photos to track progress.</string>

 If you run on a physical phone, the app talks to the coach server over your
 LAN. iOS release builds block plain HTTP — for a local dev run that's fine,
 but if blocked add an ATS exception for your server IP in Info.plist.
================================================================
NOTE
echo "Done. Now: flutter run"
