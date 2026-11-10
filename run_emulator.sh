#!/usr/bin/env bash
set -e

export JAVA_HOME="/home/pez/.local/share/jdk21"
export ANDROID_HOME="/home/pez/Android/Sdk"
export ANDROID_SDK_ROOT="/home/pez/Android/Sdk"
export PATH="/home/pez/.local/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# Check if an emulator is already running
if ! adb devices | grep -q "emulator-"; then
  echo "🚀 Avvio emulatore Android (Pixel_8_API_35)..."
  nohup "$ANDROID_HOME/emulator/emulator" -avd Pixel_8_API_35 -gpu host -no-snapshot-load >/tmp/android_emulator.log 2>&1 &
  echo "⏳ Attendo il boot di Android..."
  adb wait-for-device
  while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    sleep 2
  done
  echo "✅ Emulatore Android pronto!"
fi

cd "/home/pez/repos/calorie-tracker-ai"
echo "🔥 Avvio Calorie Tracker AI su Android..."
flutter run -d emulator-5554
