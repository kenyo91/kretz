#!/usr/bin/env bash
# Uso (con Flutter instalado): bash setup.sh  ->  genera build/app/outputs/flutter-apk/app-release.apk
set -e
flutter create --platforms=android --org com.kakeo --project-name kakeo _gen
cp -r _gen/android android && rm -rf _gen
sed -i 's/android:label="[^"]*"/android:label="Kakeo"/' android/app/src/main/AndroidManifest.xml
flutter pub get
flutter build apk --release
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
