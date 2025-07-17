#!/bin/bash

set -e

echo "🔧 Setting up Android SDK for Flutter development..."

# Set up Java from Android Studio
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"

echo "☕ Using Java from Android Studio: $JAVA_HOME"
java -version

# Create Android SDK directory
ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
echo "📁 Creating Android SDK directory at $ANDROID_SDK_ROOT..."
mkdir -p "$ANDROID_SDK_ROOT"

# Download command line tools
echo "📥 Downloading Android command line tools..."
cd "$ANDROID_SDK_ROOT"
curl -O https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip

# Extract command line tools
echo "📦 Extracting command line tools..."
unzip -q commandlinetools-mac-11076708_latest.zip
mkdir -p cmdline-tools/latest
mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
rm commandlinetools-mac-11076708_latest.zip

# Add to PATH temporarily
export ANDROID_SDK_ROOT
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$PATH"

# Accept licenses
echo "📋 Accepting Android SDK licenses..."
yes | sdkmanager --licenses

# Install essential packages
echo "📱 Installing Android SDK packages..."
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Install emulator
echo "🎮 Installing Android emulator..."
sdkmanager "emulator" "system-images;android-34;google_apis;arm64-v8a"

# Configure Flutter
echo "⚙️ Configuring Flutter to use Android SDK..."
flutter config --android-sdk "$ANDROID_SDK_ROOT"

# Create AVD
echo "📱 Creating Android Virtual Device..."
echo "no" | avdmanager create avd -n "Pixel_7_API_34" -k "system-images;android-34;google_apis;arm64-v8a"

# Add to shell profile
echo "🔧 Adding environment variables to shell profile..."
if [[ "$SHELL" == *"zsh"* ]]; then
    PROFILE_FILE="$HOME/.zshrc"
else
    PROFILE_FILE="$HOME/.bash_profile"
fi

echo "" >> "$PROFILE_FILE"
echo "# Android SDK configuration" >> "$PROFILE_FILE"
echo "export JAVA_HOME=\"$JAVA_HOME\"" >> "$PROFILE_FILE"
echo "export ANDROID_SDK_ROOT=\"$ANDROID_SDK_ROOT\"" >> "$PROFILE_FILE"
echo "export PATH=\"\$JAVA_HOME/bin:\$PATH\"" >> "$PROFILE_FILE"
echo "export PATH=\"\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$PATH\"" >> "$PROFILE_FILE"
echo "export PATH=\"\$ANDROID_SDK_ROOT/platform-tools:\$PATH\"" >> "$PROFILE_FILE"
echo "export PATH=\"\$ANDROID_SDK_ROOT/emulator:\$PATH\"" >> "$PROFILE_FILE"

echo "✅ Android SDK setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Restart your terminal or run: source $PROFILE_FILE"
echo "2. Run: flutter doctor"
echo "3. Start emulator: flutter emulators --launch Pixel_7_API_34"
echo "4. Run your app: flutter run -d android"
echo ""
echo "🔄 Please restart your terminal session for the changes to take effect." 