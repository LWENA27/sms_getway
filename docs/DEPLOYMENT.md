# Deployment Guide

## Prerequisites

- Flutter SDK 3.0+
- Android Studio / Xcode
- Git
- Supabase account
- Android device (for SMS functionality)

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/LWENA27/sms_getway.git
cd sms_getway
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Supabase

Update `lib/core/constants.dart` with your Supabase credentials:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

### 4. Database Setup

The database is already configured. To verify:

```bash
cd /home/lwena/sms_getway
supabase migration list
```

Expected output:
```
Local          | Remote         | Time (UTC)
20251222223134 | 20251222223134 | 2025-12-22 22:31:34
```

## Development

### Run on Emulator/Device

```bash
# Android
flutter run

# Specific device
flutter devices
flutter run -d <device_id>
```

### Hot Reload

Press `r` in terminal for hot reload
Press `R` for hot restart

## Production Build

### Android APK

```bash
# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android App Bundle (for Play Store)

```bash
# Build app bundle
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### Code Signing (Android)

1. Create keystore:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

2. Create `android/key.properties`:
```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=<path-to-keystore>
```

3. Update `android/app/build.gradle`:
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## Testing

### Unit Tests

```bash
flutter test
```

### Integration Tests

```bash
flutter test integration_test
```

### Code Coverage

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Performance Optimization

### Build Optimization

```bash
# Reduce APK size
flutter build apk --release --split-per-abi

# Outputs:
# app-armeabi-v7a-release.apk
# app-arm64-v8a-release.apk
# app-x86_64-release.apk
```

### Obfuscation

```bash
flutter build apk --release --obfuscate --split-debug-info=./debug-info
```

## Continuous Integration

### GitHub Actions Example

```yaml
name: Build and Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.0.0'
      - run: flutter pub get
      - run: flutter test
      - run: flutter build apk --release
```

## Deployment Checklist

- [ ] Update app version in `pubspec.yaml`
- [ ] Update `AppConstants.appVersion`
- [ ] Test on multiple devices
- [ ] Run all tests
- [ ] Build release APK/AAB
- [ ] Test release build
- [ ] Upload to Play Store
- [ ] Create release notes
- [ ] Tag release in Git

## Monitoring

### Error Tracking

Consider integrating:
- Firebase Crashlytics
- Sentry
- Custom error logging

### Analytics

Options:
- Google Analytics
- Firebase Analytics
- Custom analytics service

## Rollback Plan

If issues occur after deployment:

1. Revert to previous release:
```bash
git checkout <previous-tag>
flutter build apk --release
```

2. Upload previous version to Play Store

3. Investigate and fix issues

4. Re-deploy when ready

## Support

For deployment issues:
- Check Flutter documentation: https://flutter.dev/docs/deployment
- Check Supabase documentation: https://supabase.com/docs
- Review application logs
- Contact support team

## Security Notes

- Never commit credentials to Git
- Use environment variables for sensitive data
- Enable ProGuard/R8 for code obfuscation
- Regularly update dependencies
- Monitor for security vulnerabilities
