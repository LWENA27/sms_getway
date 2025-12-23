## SMS Gateway - Quick Reference Guide

### 🚀 Getting Started in 5 Minutes

1. **Get Supabase Credentials:**
   - Visit https://supabase.com
   - Create a project
   - Copy URL & Anon Key

2. **Update Configuration:**
   - Open `lib/core/constants.dart`
   - Paste credentials

3. **Create Database:**
   - In Supabase SQL Editor
   - Paste content from `database/schema.sql`
   - Execute

4. **Start Coding:**
   - Open `IMPLEMENTATION_GUIDE.md`
   - Follow step-by-step instructions

---

### 📚 File Navigation

| File | Purpose | Read When |
|------|---------|-----------|
| README.md | Project overview | First - get the big picture |
| IMPLEMENTATION_GUIDE.md | Step-by-step setup | Starting development |
| ARCHITECTURE.md | System design | Understanding the structure |
| PROJECT_SETUP.md | Setup checklist | Verifying everything is ready |
| constants.dart | App configuration | Setting up credentials |
| theme.dart | UI styling | Customizing look & feel |
| Models (*.dart) | Data structures | Understanding data flow |
| Services (*.dart) | Business logic | Implementing features |

---

### 🔑 Key Classes & Files

```
Core Configuration
├── AppConstants              → lib/core/constants.dart
├── AppTheme                  → lib/core/theme.dart
│
Data Models
├── User                      → lib/auth/user_model.dart
├── Contact                   → lib/contacts/contact_model.dart
├── Group & GroupMember       → lib/groups/group_model.dart
├── SmsLog                    → lib/sms/sms_log_model.dart
│
Services
├── SupabaseService           → lib/api/supabase_service.dart
├── SmsSenderService          → lib/sms/sms_sender.dart
├── AuthService              → lib/api/auth_service.dart
│
Screens (To be implemented)
├── LoginScreen              → lib/auth/login_screen.dart
├── RegisterScreen           → lib/auth/register_screen.dart
├── AddContact               → lib/contacts/add_contact.dart
├── GroupScreen              → lib/groups/group_screen.dart
├── BulkSmsScreen            → lib/sms/bulk_sms_screen.dart
├── SmsLogs                  → lib/sms/sms_logs.dart
```

---

### 🔐 Database Tables Quick Reference

```sql
-- Quick table overview
users              → Login & profile data
contacts           → Phone numbers & names  
groups             → SMS distribution lists
group_members      → Links contacts to groups
sms_logs           → History of all SMS sent
api_keys           → For Phase 2 integration
audit_logs         → Compliance & monitoring
```

---

### 📱 Android Permissions

Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
```

---

### 🎨 Theme Colors

```dart
Primary:     #2196F3 (Blue)
Secondary:   #00BCD4 (Cyan)
Accent:      #FF6B6B (Red)
Success:     #4CAF50 (Green)
Warning:     #FFC107 (Amber)
Error:       #FF5252 (Red)
```

---

### 📊 Data Model Quick Reference

```dart
// User
User(
  id: 'uuid',
  email: 'user@example.com',
  name: 'John Doe',
  phoneNumber: '+255712345678',
  role: 'user',
  createdAt: DateTime.now(),
)

// Contact
Contact(
  id: 'uuid',
  userId: 'uuid',
  name: 'Jane Doe',
  phoneNumber: '+255722345678',
  createdAt: DateTime.now(),
)

// Group
Group(
  id: 'uuid',
  userId: 'uuid',
  groupName: 'Marketing Team',
  createdAt: DateTime.now(),
  memberIds: ['contact1', 'contact2'],
)

// SmsLog
SmsLog(
  id: 'uuid',
  userId: 'uuid',
  sender: '+255712345678',
  recipient: '+255722345678',
  message: 'Hello World',
  status: 'sent',
  createdAt: DateTime.now(),
)
```

---

### 🔧 Common Operations

```dart
// Validate phone number
SmsSenderService.validatePhoneNumber('+255712345678')

// Format phone number
SmsSenderService.formatPhoneNumber('0712345678')

// Validate message
SmsSenderService.validateMessage('Hello World')

// Split long message
SmsSenderService.splitMessage(longMessage)

// Send SMS
await SmsSenderService.sendSms(
  phoneNumber: '+255712345678',
  message: 'Hello',
)

// Send bulk SMS
await SmsSenderService.sendBulkSms(
  phoneNumbers: [...],
  message: 'Hello',
)
```

---

### 🚨 Rate Limits (Phase 1)

```
Max SMS per minute:  30
Max SMS per day:     500
Message max length:  160 characters
```

---

### 🔄 Development Order

1. **Authentication**
   - Implement login/register screens
   - Test auth service

2. **Contacts**
   - Add contact screen
   - Contact list view
   - CSV import

3. **Groups**
   - Create group screen
   - Add members to group
   - View groups

4. **SMS**
   - Bulk SMS screen
   - SMS sending logic
   - SMS logs view

5. **Polish**
   - Error handling
   - Loading states
   - Empty states

---

### 🧪 Testing Checklist

- [ ] Can user sign up?
- [ ] Can user login?
- [ ] Can user add contact?
- [ ] Can user import from CSV?
- [ ] Can user create group?
- [ ] Can user add contact to group?
- [ ] Can user send SMS?
- [ ] Is SMS logged?
- [ ] Are rate limits enforced?
- [ ] Is data secured (RLS)?

---

### 🐛 Debugging Tips

```dart
// Check current user
print(Supabase.instance.client.auth.currentUser);

// Print API responses
print(response); 

// Check SMS status
print(SmsLog.status);

// Verify phone number format
print(SmsSenderService.formatPhoneNumber(phone));
```

---

### 📞 Important Numbers (Tanzania)

| Provider | Prefix | Type |
|----------|--------|------|
| Vodacom | 0741-0755 | GSM |
| Airtel | 0701-0756 | GSM |
| Tigo | 0761-0774 | GSM |
| Halotel | 0777-0787 | GSM |

All should be formatted as: `+255` + number without leading 0

---

### 💰 Cost Considerations

| Phase | Cost | Provider |
|-------|------|----------|
| Phase 1 | FREE | Supabase (free tier) |
| Phase 2 | $5-20/month | Backend server |
| Phase 3 | $0.01-0.05/SMS | Africa's Talking, Twilio, Beem |

---

### 🎯 Key Metrics for MVP

| Metric | Target | Status |
|--------|--------|--------|
| App size | < 100MB | ✅ Flutter default |
| Startup time | < 2s | ⏳ TBD |
| SMS send time | < 1s | ⏳ TBD |
| DB query time | < 500ms | ✅ With indexes |
| Auth response | < 2s | ✅ Supabase |

---

### 🚀 Deployment Steps (Later)

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle

# Install on device
flutter install

# Check build info
flutter build apk --info
```

---

### 📖 Documentation Files Explained

| File | Content |
|------|---------|
| README.md | Complete project overview & specifications |
| IMPLEMENTATION_GUIDE.md | Step-by-step implementation instructions |
| ARCHITECTURE.md | System design & technical details |
| PROJECT_SETUP.md | Setup verification checklist |
| QUICK_REFERENCE.md | This file - quick lookups |

---

### ⚡ Pro Tips

1. **Use models for everything** - Type safety prevents bugs
2. **Validate early** - Check inputs before processing
3. **Log everything** - SMS logs are crucial for debugging
4. **Test on device** - Emulators can't send SMS
5. **Backup RLS policies** - Security is critical
6. **Monitor rate limits** - Prevent SIM blocking
7. **Plan for Phase 2** - Start backend design early

---

### 🔗 Useful Links

- [Supabase Docs](https://supabase.com/docs)
- [Flutter Docs](https://docs.flutter.dev)
- [Material Design](https://material.io)
- [PostgreSQL Docs](https://www.postgresql.org/docs)
- [Android SMS API](https://developer.android.com/reference/android/telephony/SmsManager)

---

### 🆘 Quick Troubleshooting

**Problem:** "Supabase connection refused"
- Solution: Check URL & Key in constants.dart

**Problem:** "SMS permission denied"
- Solution: Request permissions at runtime

**Problem:** "Phone number invalid"
- Solution: Use formatPhoneNumber() utility

**Problem:** "Rate limit exceeded"
- Solution: Check quota, wait before retrying

**Problem:** "Database connection timeout"
- Solution: Check internet connection

---

### 📝 Common Code Snippets

```dart
// Initialize Supabase
await Supabase.initialize(
  url: AppConstants.supabaseUrl,
  anonKey: AppConstants.supabaseAnonKey,
);

// Get current user
final user = Supabase.instance.client.auth.currentUser;

// Add contact
await Supabase.instance.client.from('contacts').insert({
  'user_id': userId,
  'name': 'John',
  'phone_number': '+255712345678',
});

// Get contacts
final contacts = await Supabase.instance.client
    .from('contacts')
    .select()
    .eq('user_id', userId);

// Log SMS
await Supabase.instance.client.from('sms_logs').insert({
  'user_id': userId,
  'sender': senderId,
  'recipient': phone,
  'message': message,
  'status': 'sent',
});
```

---

**Last Updated:** December 22, 2025  
**Keep this file handy for quick reference!**
