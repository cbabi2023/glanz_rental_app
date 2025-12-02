# App Icon Setup Guide

The GLANZ logo has been configured as the app icon. Follow these steps to generate all required icon sizes.

## Current Setup

- Source icon: `assets/icon/app_icon.png` (copied from `lib/assets/png/glanzicon.png`)
- Icon size: 604x489 pixels (not square - consider creating a 1024x1024 square version for best results)

## Steps to Generate Icons

1. **Install dependencies** (if not already done):
   ```bash
   flutter pub get
   ```

2. **Generate app icons** for all platforms:
   ```bash
   flutter pub run flutter_launcher_icons
   ```

   Or if using Flutter 3.x:
   ```bash
   dart run flutter_launcher_icons
   ```

3. **Clean and rebuild** your app:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Note About Icon Dimensions

The current icon is 604x489 pixels (not square). For best results:

- **Recommended**: Create a square version (1024x1024 pixels) with the logo centered
- The `flutter_launcher_icons` package will automatically crop/add padding to create square icons
- For Android adaptive icons, a square source image works best

## What Will Be Generated

The package will automatically generate icons for:
- ✅ Android (all densities: mdpi, hdpi, xhdpi, xxhdpi, xxxhdpi)
- ✅ iOS (all required sizes)
- ✅ Web (favicon and PWA icons)
- ✅ Windows
- ✅ macOS

## Manual Icon Update (Alternative)

If you want to manually update icons, you can:
1. Create square versions of your icon in different sizes
2. Replace the files in:
   - Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
   - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Verification

After generating icons, you can verify they were created by checking:
- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png`

## Troubleshooting

If icons don't appear after generation:
1. Uninstall the app completely from your device/emulator
2. Run `flutter clean`
3. Rebuild and install: `flutter run`

