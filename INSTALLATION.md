# 📥 Installation Guide - SMS Gateway Pro

Quick and easy steps to download and run SMS Gateway Pro on your machine.

## Prerequisites

Before installing, make sure you have:

- **Flutter SDK 3.0+** - [Download Flutter](https://flutter.dev/docs/get-started/install)
- **Git** - [Download Git](https://git-scm.com/download/win)
- **Android Device** (for SMS functionality) - Android 5.0 (API 21) or higher
- **Code Editor** - VS Code or Android Studio (recommended)

## Installation Steps

### 1. Clone the Repository

```bash
git clone https://github.com/LWENA27/sms_getway.git
cd sms_getway
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Flutter (if first time)

```bash
flutter doctor
```

This checks your environment. Fix any issues reported.

### 4. Connect Android Device

- Enable USB Debugging on your Android phone:
  - Settings → Developer Options → USB Debugging (enable)
- Connect phone to computer via USB
- Verify connection:
  ```bash
  flutter devices
  ```

### 5. Run the App

```bash
flutter run
```

Or run with build optimization:
```bash
flutter run --release
```

---

## 🔧 Configuration

### Supabase Setup (Already Configured)

The app is pre-configured with Supabase backend:
- **Project URL**: `https://kzjgdeqfmxkmpmadtbpb.supabase.co`
- No additional setup needed!

### Android Permissions

All required permissions are already configured:
- ✅ SEND_SMS
- ✅ READ_SMS
- ✅ READ_PHONE_STATE
- ✅ READ_CONTACTS

---

## 🆘 Troubleshooting

### Issue: Flutter not found
**Solution**: Add Flutter to your PATH or install Flutter properly

```bash
# Check installation
flutter doctor -v
```

### Issue: Device not detected
**Solution**: 
- Enable USB Debugging on device
- Install USB drivers (for Windows)
- Try: `adb kill-server && adb start-server`

### Issue: Build fails on first run
**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

### Issue: App crashes on startup
**Solution**:
- Make sure device is connected
- Clear app data: Settings → Apps → SMS Gateway Pro → Storage → Clear Data
- Reinstall the app

---

## 📱 First Time Setup

When you first open the app:

1. **Sign Up** - Create an account with email/password
2. **Create Workspace** - Create or join an organization
3. **Grant Permissions** - Allow SMS and contact access
4. **Import Contacts** - (Optional) Import from CSV or device contacts
5. **Start Sending** - Create groups and send SMS!

---

## 📚 Additional Resources

- [Developer Guide](DEVELOPER.md) - For developers
- [API Documentation](API_DOCUMENTATION.md) - For API integration
- [Roadmap](ROADMAP.md) - Upcoming features
- [Supabase Details](SUPABASE.md) - Database structure

---

## ✅ Verify Installation

After running `flutter run`, you should see:

```
✓ Device is ready to accept commands
✓ App launched successfully
✓ You can now use SMS Gateway Pro
```

Enjoy! 🎉
