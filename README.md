# 📱 SMS Gateway Pro

**Professional Bulk SMS Management System**

A multi-tenant SMS gateway application for bulk messaging with enterprise-grade features. Built with Flutter and Supabase, enabling organizations to send SMS through their Android phones with complete data isolation.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase)](https://supabase.com)

---

## ✨ Features

### 📞 SMS Management
- **Native Android SMS** - Send SMS directly via device SIM card
- **Bulk Messaging** - Send to multiple contacts with one click
- **SMS Logs** - Track delivery status and history
- **Automatic Sending** - No manual intervention required

### 👥 Contact Management
- **Contact List** - Add, edit, delete contacts
- **CSV Import** - Bulk import contacts from CSV files
- **Phone Validation** - Automatic phone number formatting
- **Search & Filter** - Quick contact lookup

### 📁 Group Management
- **Create Groups** - Organize contacts into groups
- **Member Management** - Add/remove group members
- **Bulk Send to Groups** - Message all group members instantly

### 🏢 Multi-Tenant Architecture
- **Workspace Isolation** - Each organization's data is completely separate
- **Multiple Workspaces** - Users can belong to multiple organizations
- **Auto-Select** - Single workspace users skip selection screen
- **Workspace Switcher** - Easy switching between organizations

### 🔐 Security
- **Supabase Authentication** - Secure email/password login
- **Row Level Security (RLS)** - Database-level access control
- **Tenant Isolation** - Data protected at database level
- **API Key Authentication** - Secure external access (coming soon)

### 🔄 Settings Backup
- **Cross-Device Sync** - Backup settings to cloud, restore on another device
- **User Settings** - Sync SMS channel, theme, language, notifications
- **Tenant Settings** - Sync workspace quotas and feature flags
- **Audit Trail** - Complete history of all backup/restore operations

### 🎨 User Experience
- **Dark Mode** - Full dark theme support
- **Modern UI** - Clean, intuitive interface
- **Responsive Design** - Works on all screen sizes
- **Real-time Feedback** - Success/failure notifications

---

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Android Studio or VS Code
- Android device (for SMS sending)
- Supabase account

### Installation

```bash
# Clone the repository
git clone https://github.com/LWENA27/sms_getway.git
cd sms_getway

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Configuration

1. **Supabase Setup** (already configured)
   - Project URL: `https://kzjgdeqfmxkmpmadtbpb.supabase.co`
   - See [SUPABASE.md](SUPABASE.md) for database details

2. **Android Permissions** (already configured in AndroidManifest.xml)
   - `SEND_SMS` - Send SMS messages
   - `READ_SMS` - Track SMS status
   - `READ_PHONE_STATE` - Check device status

3. **Run on Device**
   ```bash
   # List connected devices
   flutter devices
   
   # Run on specific device
   flutter run -d <device_id>
   ```

---

## 📖 Usage

### 1. Login
- Open the app and login with your credentials
- First-time users need to be added by an admin

### 2. Add Contacts
- Navigate to **Contacts** tab
- Tap **+** button to add a contact
- Or use **Import CSV** for bulk import

### 3. Create Groups
- Go to **Groups** tab
- Create a new group
- Add contacts to the group

### 4. Send SMS
- Open **Send SMS** tab
- Select contacts or a group
- Type your message
- Tap **Send** - SMS sent automatically!

### 5. View Logs
- Check **Logs** tab for delivery status
- See sent, failed, and pending messages

---

## ⚙️ SMS Implementation Details

### Native Android SMS Sending

The app uses Android's native SMS sending capabilities via platform channels:

**How It Works:**
1. User selects "This Phone" as SMS channel in Settings
2. Taps "Send SMS" with selected contacts
3. Flutter calls Kotlin platform channel via MethodChannel
4. Kotlin invokes SmsManager to send SMS via device SIM
5. Delivery status logged to database

**Service Architecture:**
- **NativeSmsService** - Manages platform channel communication
- **SmsService** - Routes to correct SMS delivery method (Native or API)
- **ApiSmsQueueService** - Polls database for pending SMS requests

**Android Implementation (`MainActivity.kt`):**
```kotlin
private val channel = "com.example.sms_gateway.sms"

setupChannel(binaryMessenger) { call ->
    when (call.method) {
        "sendSms" -> {
            val phoneNumber = call.argument<String>("phoneNumber")!!
            val message = call.argument<String>("message")!!
            sendSmsViaNative(phoneNumber, message)
        }
    }
}

private fun sendSmsViaNative(phoneNumber: String, message: String) {
    val smsManager = SmsManager.getDefault()
    smsManager.sendTextMessage(phoneNumber, null, message, null, null)
}
```

**Flutter Implementation (`sms_service.dart`):**
```dart
Future<bool> sendViaNativeAndroid({
    required String phoneNumber,
    required String message,
}) async {
    try {
        final result = await platform.invokeMethod<bool>('sendSms', {
            'phoneNumber': phoneNumber,
            'message': message,
        });
        return result ?? false;
    } catch (e) {
        debugPrint('Error sending native SMS: $e');
        return false;
    }
}
```

### API Queue Processing

The app can also send SMS via external APIs like QuickSMS:

**Queue Flow:**
1. External system calls API endpoint with SMS request
2. Edge function creates record in `sms_requests` table with status='pending'
3. Flutter app polls database every 30 seconds (ApiSmsQueueService)
4. Service fetches pending requests
5. Checks user's selected SMS channel (Native or QuickSMS)
6. Routes to appropriate SMS service
7. Updates request status: pending → processing → sent/failed

**User's SMS Channel Choice:**
The app respects the user's preference in Settings:
- **"This Phone"** → Routes to native Android SMS via platform channel
- **"QuickSMS API"** → Routes to QuickSMS HTTP API

**Queue Service Code (`api_sms_queue_service.dart`):**
```dart
Future<void> _processSingleRequest(SmsRequest request) async {
    try {
        // Get user's selected SMS channel
        final channel = await SmsService.getSelectedChannel();
        
        bool success;
        if (channel == 'quickSMS') {
            // Send via QuickSMS API
            success = await SmsService.sendViaQuickSms(
                phoneNumber: request.phoneNumber,
                message: request.message,
            );
        } else {
            // Send via Native Android SMS
            success = await SmsService.sendViaNativeAndroid(
                phoneNumber: request.phoneNumber,
                message: request.message,
            );
        }
        
        // Update status in database
        await _updateRequestStatus(
            request.id,
            success ? 'sent' : 'failed'
        );
    } catch (e) {
        // Log error and mark as failed
    }
}
```

### Settings Backup During SMS Sending

When users backup settings, the SMS channel preference is included:
- If set to "This Phone", native SMS will be used
- If set to "QuickSMS", API-based sending will be used
- Backup restores this preference on different devices
- Queue service respects the restored preference

### Troubleshooting SMS Sending

**SMS not sending despite being pending?**
1. Check that user has selected an SMS channel in Settings
2. Verify Settings → API Queue Settings has "Auto-start" enabled
3. Check that app has SMS permissions in Android
4. Verify phone number is valid
5. Check Supabase database for error messages in sms_logs

**Native SMS fails silently?**
1. Ensure device has an active SIM card
2. Check Android OS permissions (not granted = silent failure)
3. Monitor logcat: `flutter logs`
4. Check sms_logs table for status='failed' entries

**API Queue not processing?**
1. Go to Settings → API Integration
2. Click "Start Processing" button manually
3. Or enable "Auto-start Queue Processing" in Settings
4. Verify API credentials are configured
5. Check network connectivity

---

```
┌─────────────────────────────────────────────┐
│              Flutter App                     │
│         (Multi-Tenant Aware)                 │
└──────────────────┬──────────────────────────┘
                   │
       ┌───────────┼───────────┐
       ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ Supabase │ │  Native  │ │   API    │
│   Auth   │ │   SMS    │ │ (Future) │
└──────────┘ └──────────┘ └──────────┘
       │           │           │
       ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│PostgreSQL│ │ Android  │ │ External │
│   RLS    │ │   SIM    │ │ Systems  │
└──────────┘ └──────────┘ └──────────┘
```

### Tech Stack

| Component | Technology |
|-----------|------------|
| Frontend | Flutter 3.0+ |
| Backend | Supabase (PostgreSQL) |
| Authentication | Supabase Auth |
| SMS Delivery | Native Android SmsManager |
| State Management | Provider |
| Local Storage | SharedPreferences |

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [README.md](README.md) | This file - Project overview |
| [SUPABASE.md](SUPABASE.md) | Database schema and setup |
| [DEVELOPER.md](DEVELOPER.md) | Technical guide for developers |
| [ROADMAP.md](ROADMAP.md) | Future features and phases |

---

## 🔒 Security Notes

- **Never commit credentials** - Supabase keys are in constants.dart
- **SMS permissions** - Required for native sending on Android
- **RLS policies** - All data protected at database level
- **Tenant isolation** - Organizations cannot see each other's data

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Commit changes: `git commit -m 'Add amazing feature'`
4. Push to branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👨‍💻 Author

**Lwena TechWareAfrica**

- GitHub: [@LWENA27](https://github.com/LWENA27)

---

## 🙏 Acknowledgments

- [Flutter](https://flutter.dev) - UI framework
- [Supabase](https://supabase.com) - Backend and database
- [Material Design](https://material.io) - Design system

---

Made with ❤️ by Lwena TechWareAfrica
