# 🚀 Release Preparation Checklist

## ✅ Pre-Release Tasks Completed

### 1. Version Management
- [x] **Version**: 1.0.0+1 (Set in pubspec.yaml)
- [x] **Version Code**: 1 (Android)
- [x] **Version Name**: "1.0.0" (Android)

### 2. App Identity
- [x] **Package Name**: Changed from `com.example.sms_gateway` to `com.lwenatech.sms_gateway`
- [x] **App Name**: "SMS Gateway Pro"
- [x] **App Description**: Professional SMS Gateway for bulk SMS management

### 3. Android Configuration
- [x] **Min SDK**: 21 (Android 5.0 - Lollipop)
- [x] **Target SDK**: 34 (Android 14 - Latest)
- [x] **Compile SDK**: Latest Flutter default
- [x] **Package Structure**: Moved from com.example to com.lwenatech
- [x] **MainActivity**: Updated package name
- [x] **MethodChannel**: Updated channel name

### 4. Security & Privacy
- [x] **Backup Rules**: Created backup_rules.xml
- [x] **Cleartext Traffic**: Disabled (usesCleartextTraffic="false")
- [x] **Permissions**: All necessary SMS permissions declared
- [x] **RLS Policies**: Database-level security enabled

### 5. Features Verified
- [x] Multi-tenant architecture
- [x] SMS sending (native Android)
- [x] Contact management (CSV/VCF import)
- [x] Group management
- [x] API integration with queue
- [x] Offline-first with Drift
- [x] Settings backup/restore
- [x] Sender ID request system
- [x] Cross-platform support (Web/Android)

---

## ⚠️ Required Actions Before Release

### 1. Create Signing Key (CRITICAL)

```bash
# Generate release keystore
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload \
  -storetype JKS

# Follow prompts:
# - Enter keystore password (SAVE THIS!)
# - Re-enter password
# - Enter your name/organization details
# - Enter key password (can be same as keystore password)
```

### 2. Configure Signing (CRITICAL)

**Create file: `android/key.properties`**
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/home/lwena/upload-keystore.jks
```

**⚠️ IMPORTANT**: Add to `.gitignore`:
```bash
echo "android/key.properties" >> .gitignore
echo "*.jks" >> .gitignore
```

### 3. Update `android/app/build.gradle.kts`

Add before `android {` block:
```kotlin
// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### 4. Create ProGuard Rules

**Create file: `android/app/proguard-rules.pro`**
```proguard
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase
-keep class io.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }

# Drift (Database)
-keep class drift.** { *; }
-keepclassmembers class * extends drift.GeneratedDatabase {
    public <init>(...);
}
```

### 5. App Icon & Splash Screen

**Current Status**: Using default Flutter launcher icon

**To Customize**:
1. Install flutter_launcher_icons package (dev dependency)
2. Add icon image to `assets/icon/icon.png` (1024x1024 PNG)
3. Run: `flutter pub run flutter_launcher_icons`

**For Splash Screen**:
1. Use flutter_native_splash package
2. Add splash image to `assets/splash/splash.png`
3. Configure in pubspec.yaml
4. Run: `flutter pub run flutter_native_splash:create`

### 6. Test Release Build

```bash
# Clean build
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Or build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Test on device
flutter install --release
```

### 7. Privacy Policy & Terms

**Required for Play Store**:
- [ ] Create privacy policy (URL required)
- [ ] Create terms of service
- [ ] Add links to app settings
- [ ] Host on website or GitHub Pages

**Content should cover**:
- Data collection (contacts, SMS logs)
- Supabase backend usage
- User data storage
- Multi-tenant data isolation
- Third-party services

### 8. Google Play Store Listing

**Required Assets**:
- [ ] App icon (512x512 PNG)
- [ ] Feature graphic (1024x500 PNG)
- [ ] Phone screenshots (at least 2)
- [ ] 7-inch tablet screenshots (optional)
- [ ] 10-inch tablet screenshots (optional)

**Store Listing**:
- [ ] Short description (80 chars max)
- [ ] Full description (4000 chars max)
- [ ] Privacy policy URL
- [ ] Support email
- [ ] Website URL (optional)

### 9. Testing Checklist

- [ ] Test on Android 5.0 (min SDK)
- [ ] Test on Android 14 (target SDK)
- [ ] Test SMS sending on real device
- [ ] Test contact import (CSV/VCF)
- [ ] Test group creation
- [ ] Test multi-tenant switching
- [ ] Test offline mode
- [ ] Test settings backup/restore
- [ ] Test on different screen sizes
- [ ] Test with different SIM cards

### 10. Final Verification

- [ ] Remove all TODO comments
- [ ] Remove all debug print statements
- [ ] Check for hardcoded credentials
- [ ] Verify Supabase connection
- [ ] Test deep links (if implemented)
- [ ] Check app permissions dialog flow
- [ ] Verify back button behavior
- [ ] Test app restart/restore state

---

## 📦 Build Commands

### Development Build
```bash
flutter run --debug
```

### Release APK (for testing)
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Release App Bundle (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Build for specific ABI (smaller APK)
```bash
flutter build apk --release --split-per-abi
# Creates separate APKs for arm64-v8a, armeabi-v7a, x86_64
```

---

## 🔐 Security Best Practices

1. **Never commit**:
   - `key.properties`
   - `*.jks` (keystore files)
   - Supabase anon keys (use env variables)
   - API keys or secrets

2. **Use environment variables**:
   ```dart
   // lib/core/constants.dart
   static const String supabaseUrl = String.fromEnvironment(
     'SUPABASE_URL',
     defaultValue: 'YOUR_DEFAULT_URL',
   );
   ```

3. **Enable ProGuard** for code obfuscation

4. **Use HTTPS** for all network calls (already configured)

---

## 📊 Version Management

**Current**: 1.0.0+1

**For updates**:
- Patch (bug fixes): 1.0.1+2
- Minor (new features): 1.1.0+3
- Major (breaking changes): 2.0.0+4

**Update in**:
- `pubspec.yaml` → version: X.X.X+X
- `android/app/build.gradle.kts` → versionCode & versionName

---

## 🚀 Next Steps

1. **Generate signing key** ⚠️ CRITICAL
2. **Configure signing** in build.gradle.kts
3. **Test release build** on real device
4. **Create store assets** (icons, screenshots)
5. **Write privacy policy**
6. **Submit to Play Store**

---

## 📞 Support & Resources

- **Play Console**: https://play.google.com/console
- **Flutter Deployment**: https://docs.flutter.dev/deployment/android
- **Android Signing**: https://developer.android.com/studio/publish/app-signing

---

## ✅ Status: READY FOR SIGNING CONFIGURATION

All code changes complete. Next step: Generate signing key and configure release signing.
