## ⚠️ FLUTTER NOT INSTALLED - SETUP GUIDE

### Problem
`flutter` command is not recognized in PowerShell. This means either:
1. Flutter SDK is not installed, OR
2. Flutter is not in your system PATH

---

## ✅ Solution

### Option 1: Install Flutter (Recommended if not installed)

**Step 1: Download Flutter**
1. Go to https://flutter.dev/docs/get-started/install/windows
2. Download the latest stable version (Windows)
3. Extract to a simple path like: `C:\flutter`

**Step 2: Add Flutter to PATH**

For Windows 10/11:
1. Press `Win + X` → Choose "System"
2. Click "Advanced system settings"
3. Click "Environment Variables..."
4. Under "System variables", click "New..."
5. Variable name: `FLUTTER_HOME`
6. Variable value: `C:\flutter` (or your extraction path)
7. Click OK

Now edit the `Path` variable:
1. Select `Path` from System variables
2. Click "Edit..."
3. Click "New"
4. Add: `C:\flutter\bin`
5. Click OK, then OK again

**Step 3: Verify Installation**

Close PowerShell and open a NEW PowerShell window, then run:
```powershell
flutter doctor
```

You should see Flutter information.

---

### Option 2: Quick Fix (If Flutter is already installed somewhere)

**Find Flutter Installation:**
```powershell
# In PowerShell, search for flutter installation
Get-ChildItem -Path "C:\" -Filter "flutter" -Recurse -Directory -ErrorAction SilentlyContinue
```

Once you find it, add it to PATH as shown in Option 1.

---

## 🚀 After Installing/Setting Up Flutter

Close and reopen PowerShell, then run:

```powershell
cd "C:\Users\LwenaTechWare\Desktop\sms_getway"

# Verify Flutter works
flutter doctor

# Get dependencies
flutter pub get

# Connect Android device with USB
# Enable USB Debugging on device

# Run app
flutter run
```

---

## 📝 Detailed Path Setup (Windows)

### For PowerShell Users:

1. Open PowerShell **AS ADMINISTRATOR**
2. Run:
```powershell
$flutterPath = "C:\flutter\bin"
[Environment]::SetEnvironmentVariable("PATH", [Environment]::GetEnvironmentVariable("PATH", "User") + ";$flutterPath", "User")
```

3. Close and reopen PowerShell
4. Test: `flutter --version`

---

## 🆘 Still Having Issues?

### Completely Fresh Installation (Nuclear Option)

1. **Download Flutter:**
   - Visit: https://flutter.dev/docs/get-started/install
   - Download Windows SDK

2. **Extract Somewhere Simple:**
   ```
   C:\flutter
   ```
   (NO spaces, NO special characters)

3. **Run Flutter Setup:**
   ```powershell
   cd C:\flutter\bin
   flutter doctor --android-licenses
   # Press 'y' for all prompts
   ```

4. **Add to System PATH:**
   - Windows Settings → Environment Variables
   - Add `C:\flutter\bin` to PATH
   - Restart computer

5. **Verify:**
   ```powershell
   flutter doctor
   ```

---

## 📱 Android Setup (After Flutter is Ready)

```powershell
# Check devices
flutter devices

# If no devices, enable USB Debugging:
# 1. Go to Settings → About phone
# 2. Tap "Build number" 7 times
# 3. Go back, open Developer options
# 4. Enable "USB Debugging"
# 5. Connect phone and authorize

# Then run app
flutter run
```

---

## ✅ Verification

Once Flutter is set up, you should see:

```powershell
PS> flutter --version
Flutter 3.x.x • channel stable
Dart 3.x.x
```

And:

```powershell
PS> flutter devices
2 connected device:
  Android Device (mobile) • emulator-5554 • android-x64 • Android 14.0
  Windows (desktop) • windows • windows-x64 • Windows 10.0.19045
```

---

## 🎯 Next Steps (Once Flutter is Installed)

```powershell
cd "C:\Users\LwenaTechWare\Desktop\sms_getway"

flutter pub get
flutter run
```

**Your app will launch on Android device! 🚀**

---

## 💡 Pro Tips

- Keep Flutter path simple (no spaces)
- Always restart PowerShell after PATH changes
- Use `flutter doctor` to check for missing dependencies
- Android Studio can help with Android SDK setup

---

Need help with specific step? Let me know!
