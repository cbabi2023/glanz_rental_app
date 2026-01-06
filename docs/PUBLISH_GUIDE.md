# Play Store Publishing Guide for Glanz Rental

## ✅ Configuration Complete!

Your app is now configured for Play Store publishing. Here's what's been set up:

1. ✅ Application ID: `com.supportta.glanz_rental`
2. ✅ App Name: "Glanz Rental"
3. ✅ Release signing configuration (ready)
4. ✅ ProGuard rules configured
5. ✅ Signing files excluded from git

## 📝 Next Steps

### Step 1: Generate Keystore File

Run this command in your project root directory:

```bash
keytool -genkey -v -keystore android/keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Important details to remember:**
- **Store password**: Create a strong password (save it securely!)
- **Key password**: Can be same as store password or different
- **Name/Organization**: Your name or company name
- **Alias**: Use `upload` (already configured)

### Step 2: Create key.properties File

1. Copy the example file:
   ```bash
   cp android/key.properties.example android/key.properties
   ```

2. Edit `android/key.properties` and fill in your actual values:
   ```
   storePassword=YOUR_ACTUAL_STORE_PASSWORD
   keyPassword=YOUR_ACTUAL_KEY_PASSWORD
   keyAlias=upload
   storeFile=../keystore.jks
   ```

3. **IMPORTANT**: Never commit `key.properties` or `keystore.jks` to git!

### Step 3: Build Release Bundle

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release
```

The output will be at: `build/app/outputs/bundle/release/app-release.aab`

### Step 4: Test Your Release Build (Optional but recommended)

```bash
# Install on a connected device
flutter install --release
```

### Step 5: Upload to Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Create a new app (if you haven't already)
3. Fill in all required information:
   - **App name**: Glanz Rental
   - **Default language**: English (or your choice)
   - **App or Game**: App
   - **Free or Paid**: Choose accordingly

### Step 6: Complete Store Listing

You'll need to provide:

1. **App Icon**: 512x512 PNG (high-res icon)
2. **Feature Graphic**: 1024x500 PNG (banner)
3. **Screenshots**: At least 2, up to 8 (phone screenshots)
4. **Short Description**: 80 characters max
5. **Full Description**: Up to 4000 characters
6. **Privacy Policy URL**: **REQUIRED** - You must have a privacy policy
7. **App Category**: Business/Productivity/etc.

### Step 7: Content Rating

Complete the content rating questionnaire. Since your app uses:
- Camera
- Gallery/Photos
- User data

You'll need to declare these in the questionnaire.

### Step 8: Data Safety

Declare what data you collect:
- ✅ Photos and videos (camera/gallery access)
- ✅ User information (customer data)
- ✅ App activity (order history)

### Step 9: Prepare Release

1. Go to **Production** → **Create new release**
2. Upload `app-release.aab` file
3. Add release notes (e.g., "Initial release")
4. Review and roll out

### Step 10: Submit for Review

- Review all sections (ensure all green checkmarks ✅)
- Click **Submit for review**

## ⏱️ Timeline

- First-time review: **1-3 days**
- Updates: Usually **few hours to 1 day**

## 🔒 Security Notes

1. **BACKUP YOUR KEYSTORE FILE!** If you lose it, you cannot update your app.
2. Store `keystore.jks` and `key.properties` in a secure location
3. Never share your keystore password
4. Consider using Google Play App Signing (Google manages your key)

## 📚 Additional Resources

- [Flutter Release Documentation](https://docs.flutter.dev/deployment/android)
- [Play Console Help](https://support.google.com/googleplay/android-developer)
- [App Bundle Guide](https://developer.android.com/guide/app-bundle)

## 🆘 Troubleshooting

**Issue**: Build fails with signing error
- **Solution**: Make sure `key.properties` exists and paths are correct

**Issue**: "Application ID already exists"
- **Solution**: Change `applicationId` in `build.gradle.kts` to something unique

**Issue**: Missing privacy policy
- **Solution**: Create a privacy policy (use templates online) and host it

Good luck with your app launch! 🚀
