# SMS Gateway - Flutter Setup Helper

## 🔍 Check if Flutter is Installed

Open PowerShell and run:
```powershell
flutter --version
```

**If you see:** `flutter : The term 'flutter' is not recognized`
→ Go to FLUTTER_SETUP.md in your project for installation guide

**If you see:** `Flutter X.X.X • channel stable`
→ Flutter is installed! Run the commands below.

---

## 🚀 Quick Setup (5 minutes)

Once Flutter is installed, run these commands in order:

### 1. Navigate to Project
```powershell
cd "C:\Users\LwenaTechWare\Desktop\sms_getway"
```

### 2. Check Flutter Installation
```powershell
flutter doctor
```

Should show:
- ✓ Flutter installed
- ✓ Android toolchain OK
- ✓ VS Code installed

### 3. Get Dependencies
```powershell
flutter pub get
```

This downloads all packages (might take 2-5 minutes first time)

### 4. Connect Android Device
- Plug Android phone via USB
- Enable USB Debugging (Settings → Developer Options → USB Debugging)
- Trust the computer on your phone

### 5. Check Connected Devices
```powershell
flutter devices
```

Should show your Android device listed

### 6. Run App
```powershell
flutter run
```

Watch for the app to appear on your Android device!

---

## ⏱️ Expected Timeline

- **First time setup:** 10-15 minutes (downloading dependencies)
- **Subsequent runs:** 30-60 seconds to rebuild and run

---

## ✅ Success Indicators

When app launches on Android:
- ✅ See login screen
- ✅ "SMS Gateway" title at top
- ✅ Email and password input fields
- ✅ Login button
- ✅ Sign up link

Test by:
1. Create a test account (any email/password)
2. Should see welcome dashboard
3. Dashboard shows "0 Contacts, 0 Groups, 0 SMS Logs"
4. Logout and login again

---

## 🆘 Common Issues

### "flutter command not found"
→ See FLUTTER_SETUP.md for installation

### "No connected devices"
→ Check USB cable, enable USB Debugging on phone

### "Build failed"
→ Run: `flutter clean` then `flutter pub get` again

### "Supabase connection error"
→ Check internet connection, verify credentials in constants.dart

---

## 📱 Android Device Requirements

- Android 5.0 or higher
- USB Debugging enabled
- USB cable (for connection)
- Google Play Services installed

---

## 🎯 Once App is Running

You can:
- Press `r` in terminal to hot reload (quick changes)
- Press `R` to restart app
- Press `q` to quit
- Rotate device to test landscape
- Check terminal for logs

---

**Everything is ready. Just install Flutter and run!**

See: FLUTTER_SETUP.md for detailed installation steps.
