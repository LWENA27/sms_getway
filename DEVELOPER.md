# 👨‍💻 Developer Guide

Technical documentation for developers working on SMS Gateway Pro.

---

## 📁 Project Structure

```
sms_getway/
├── lib/                          # Flutter source code
│   ├── main.dart                 # App entry point
│   ├── api/                      # Backend services
│   │   ├── native_sms_service.dart    # Platform channel for Android SMS
│   │   └── supabase_service.dart      # Supabase database operations
│   ├── auth/                     # Authentication
│   │   └── user_model.dart       # User data model
│   ├── contacts/                 # Contact management
│   │   └── contact_model.dart    # Contact data model
│   ├── core/                     # Core utilities
│   │   ├── constants.dart        # App constants & configuration
│   │   ├── tenant_service.dart   # Multi-tenant state management
│   │   ├── theme.dart            # App theme definitions
│   │   └── theme_provider.dart   # Theme state (dark/light mode)
│   ├── groups/                   # Group management
│   │   └── group_model.dart      # Group data model
│   ├── screens/                  # UI screens
│   │   ├── bulk_sms_screen.dart      # Send bulk SMS
│   │   ├── contacts_screen.dart      # Contact list & management
│   │   ├── groups_screen.dart        # Group list & management
│   │   ├── profile_screen.dart       # User profile
│   │   ├── settings_screen.dart      # App settings
│   │   ├── sms_logs_screen.dart      # SMS history/logs
│   │   └── tenant_selector_screen.dart # Workspace selection
│   ├── services/                 # Additional services
│   │   └── sms_service.dart      # SMS business logic
│   ├── settings/                 # Settings module (empty)
│   └── sms/                      # SMS module
│       ├── sms_log_model.dart    # SMS log data model
│       └── sms_sender.dart       # SMS sending logic
├── android/                      # Android native code
│   └── app/src/main/kotlin/com/example/sms_gateway/
│       └── MainActivity.kt       # Native SMS implementation
├── supabase/                     # Database
│   └── migrations/               # SQL migration files
│       └── 20251222223134_remote_schema.sql
├── README.md                     # Project overview
├── SUPABASE.md                   # Database documentation
├── DEVELOPER.md                  # This file
├── ROADMAP.md                    # Future features
└── pubspec.yaml                  # Flutter dependencies
```

---

## 🏗️ Architecture Overview

### Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer (Screens)                      │
│   contacts_screen  │  bulk_sms_screen  │  sms_logs_screen   │
├─────────────────────────────────────────────────────────────┤
│                     State Management                         │
│              Provider (ThemeProvider, TenantService)         │
├─────────────────────────────────────────────────────────────┤
│                      Service Layer                           │
│   supabase_service.dart  │  sms_service.dart                │
├─────────────────────────────────────────────────────────────┤
│                      Data Layer                              │
│   contact_model  │  group_model  │  sms_log_model           │
├─────────────────────────────────────────────────────────────┤
│                    Platform Layer                            │
│   native_sms_service.dart  ←→  MainActivity.kt (Kotlin)     │
├─────────────────────────────────────────────────────────────┤
│                      Backend                                 │
│              Supabase (PostgreSQL + Auth + RLS)              │
└─────────────────────────────────────────────────────────────┘
```

### Multi-Tenant Flow

```
1. User logs in via Supabase Auth
2. App queries client_product_access for user's tenants
3. If 1 tenant → auto-select
4. If 2+ tenants → show TenantSelectorScreen
5. Selected tenant_id stored in TenantService
6. All queries include tenant_id filter
7. RLS policies enforce isolation at database level
```

---

## 🔧 Core Components

### 1. Constants (`lib/core/constants.dart`)

All app configuration in one place:

```dart
class AppConstants {
  // Supabase
  static const String supabaseUrl = 'https://kzjgdeqfmxkmpmadtbpb.supabase.co';
  static const String supabaseAnonKey = 'eyJ...';
  
  // App
  static const String appName = 'SMS Gateway Pro';
  static const String appVersion = '1.0.0';
  
  // Rate Limiting
  static const int maxSmsPerMinute = 30;
  static const int maxSmsPerDay = 500;
  
  // SMS Status
  static const String smsSent = 'sent';
  static const String smsFailed = 'failed';
  static const String smsDelivered = 'delivered';
  static const String smsPending = 'pending';
}
```

### 2. Theme Provider (`lib/core/theme_provider.dart`)

Manages dark/light mode:

```dart
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
```

### 3. Tenant Service (`lib/core/tenant_service.dart`)

Manages current workspace:

```dart
class TenantService {
  String? _currentTenantId;
  List<TenantModel> _tenants = [];
  
  String? getTenantId() => _currentTenantId;
  
  Future<void> selectTenant(TenantModel tenant) async {
    _currentTenantId = tenant.id;
    // Store in SharedPreferences
  }
}
```

---

## 📱 Native SMS Implementation

### Platform Channel (Flutter → Kotlin)

**Flutter Side** (`lib/api/native_sms_service.dart`):

```dart
class NativeSmsService {
  static const platform = MethodChannel('com.example.sms_gateway/sms');
  
  static Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await platform.invokeMethod<bool>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result == true;
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      return false;
    }
  }
  
  static Future<Map<String, dynamic>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    final result = await platform.invokeMethod<Map>('sendBulkSms', {
      'phoneNumbers': phoneNumbers,
      'message': message,
    });
    return {
      'successCount': result?['successCount'] ?? 0,
      'failedNumbers': result?['failedNumbers'] ?? [],
    };
  }
}
```

**Android Side** (`android/.../MainActivity.kt`):

```kotlin
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.sms_gateway/sms"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendSms" -> {
                        val phoneNumber = call.argument<String>("phoneNumber")
                        val message = call.argument<String>("message")
                        sendSms(phoneNumber!!, message!!, result)
                    }
                    "sendBulkSms" -> {
                        val phoneNumbers = call.argument<List<String>>("phoneNumbers")
                        val message = call.argument<String>("message")
                        sendBulkSms(phoneNumbers!!, message!!, result)
                    }
                }
            }
    }
    
    private fun sendSms(phoneNumber: String, message: String, result: MethodChannel.Result) {
        val smsManager = getSystemService(SmsManager::class.java)
        smsManager.sendTextMessage(phoneNumber, null, message, null, null)
        result.success(true)
    }
}
```

### Required Android Permissions

In `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
```

---

## 🗄️ Database Queries

### Pattern: All Queries Include tenant_id

```dart
// ✅ CORRECT - Always filter by tenant_id
final contacts = await supabase
    .from('sms_gateway.contacts')
    .select()
    .eq('tenant_id', currentTenantId)
    .eq('user_id', currentUserId);

// ❌ WRONG - Never query without tenant filter
final contacts = await supabase
    .from('sms_gateway.contacts')
    .select();
```

### Common Queries

**Get Contacts:**
```dart
Future<List<Contact>> getContacts() async {
  final response = await supabase
      .from('sms_gateway.contacts')
      .select()
      .eq('tenant_id', tenantId)
      .eq('user_id', userId)
      .order('name', ascending: true);
  
  return response.map((json) => Contact.fromJson(json)).toList();
}
```

**Add Contact:**
```dart
Future<Contact> addContact(Contact contact) async {
  final data = contact.toJson()
    ..['tenant_id'] = tenantId
    ..['user_id'] = userId;
  
  final response = await supabase
      .from('sms_gateway.contacts')
      .insert(data)
      .select()
      .single();
  
  return Contact.fromJson(response);
}
```

**Log SMS:**
```dart
Future<void> logSms({
  required String recipient,
  required String message,
  required String status,
}) async {
  await supabase.from('sms_gateway.sms_logs').insert({
    'tenant_id': tenantId,
    'user_id': userId,
    'recipient': recipient,
    'message': message,
    'status': status,
    'sent_at': DateTime.now().toIso8601String(),
  });
}
```

---

## ➕ Adding New Features

### Step 1: Create Data Model

```dart
// lib/new_feature/new_model.dart
class NewModel {
  final String id;
  final String tenantId;
  final String userId;
  final String name;
  final DateTime createdAt;
  
  NewModel({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.name,
    required this.createdAt,
  });
  
  factory NewModel.fromJson(Map<String, dynamic> json) {
    return NewModel(
      id: json['id'],
      tenantId: json['tenant_id'],
      userId: json['user_id'],
      name: json['name'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'user_id': userId,
    'name': name,
    'created_at': createdAt.toIso8601String(),
  };
}
```

### Step 2: Add Database Table

```sql
-- In Supabase SQL Editor
CREATE TABLE sms_gateway.new_feature (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE sms_gateway.new_feature ENABLE ROW LEVEL SECURITY;

-- Add policies
CREATE POLICY "Users can view own data"
  ON sms_gateway.new_feature
  FOR SELECT
  USING (tenant_id = get_tenant_id() AND user_id = auth.uid());

CREATE POLICY "Users can insert own data"
  ON sms_gateway.new_feature
  FOR INSERT
  WITH CHECK (tenant_id = get_tenant_id() AND user_id = auth.uid());
```

### Step 3: Create Service Methods

```dart
// lib/api/supabase_service.dart

Future<List<NewModel>> getNewFeatures() async {
  final response = await supabase
      .from('sms_gateway.new_feature')
      .select()
      .eq('tenant_id', tenantId)
      .eq('user_id', userId);
  
  return response.map((json) => NewModel.fromJson(json)).toList();
}

Future<NewModel> addNewFeature(NewModel item) async {
  final data = item.toJson()
    ..['tenant_id'] = tenantId
    ..['user_id'] = userId;
  
  final response = await supabase
      .from('sms_gateway.new_feature')
      .insert(data)
      .select()
      .single();
  
  return NewModel.fromJson(response);
}
```

### Step 4: Create UI Screen

```dart
// lib/screens/new_feature_screen.dart
class NewFeatureScreen extends StatefulWidget {
  const NewFeatureScreen({super.key});
  
  @override
  State<NewFeatureScreen> createState() => _NewFeatureScreenState();
}

class _NewFeatureScreenState extends State<NewFeatureScreen> {
  List<NewModel> items = [];
  bool isLoading = true;
  
  @override
  void initState() {
    super.initState();
    loadItems();
  }
  
  Future<void> loadItems() async {
    setState(() => isLoading = true);
    items = await SupabaseService().getNewFeatures();
    setState(() => isLoading = false);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Feature')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(title: Text(item.name));
              },
            ),
    );
  }
}
```

### Step 5: Add Navigation

```dart
// In main.dart or navigation
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const NewFeatureScreen()),
);
```

---

## 🧪 Testing

### Run All Tests
```bash
flutter test
```

### Run Specific Test
```bash
flutter test test/contact_test.dart
```

### Test Database Queries
```dart
// test/supabase_test.dart
void main() {
  test('getContacts returns list', () async {
    final service = SupabaseService();
    final contacts = await service.getContacts();
    expect(contacts, isA<List<Contact>>());
  });
}
```

---

## 🔨 Build Commands

### Development
```bash
flutter run                    # Run on connected device
flutter run -d chrome          # Run on Chrome (limited features)
flutter run --release          # Run release build
```

### Build APK
```bash
flutter build apk              # Build debug APK
flutter build apk --release    # Build release APK
flutter build appbundle        # Build AAB for Play Store
```

### Output Locations
```
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

---

## 🐛 Debugging

### Flutter Logs
```bash
flutter logs                   # View device logs
```

### Debug Prints
```dart
debugPrint('📱 Sending SMS to $phoneNumber');
debugPrint('✅ Success: $result');
debugPrint('❌ Error: $error');
```

### Check RLS Issues
```sql
-- In Supabase SQL Editor
SELECT * FROM sms_gateway.contacts 
WHERE tenant_id = 'your-tenant-id' 
AND user_id = 'your-user-id';
```

---

## 🔐 Security Best Practices

### 1. Always Filter by Tenant
```dart
// Every query MUST include tenant_id
.eq('tenant_id', currentTenantId)
```

### 2. Never Expose Keys in Code
```dart
// ✅ Use environment variables
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

// ❌ Don't commit real keys
const supabaseAnonKey = 'eyJ...'; // Already in constants.dart
```

### 3. Validate User Input
```dart
if (!RegExp(AppConstants.phonePattern).hasMatch(phone)) {
  throw Exception('Invalid phone number');
}
```

### 4. Handle Permissions
```dart
final hasPermission = await NativeSmsService.checkSmsPermission();
if (!hasPermission) {
  await NativeSmsService.requestSmsPermission();
}
```

---

## 📚 Key Files Reference

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, auth wrapper, navigation |
| `lib/core/constants.dart` | All configuration values |
| `lib/api/native_sms_service.dart` | Flutter ↔ Android bridge |
| `lib/api/supabase_service.dart` | Database operations |
| `lib/core/tenant_service.dart` | Multi-tenant state |
| `android/.../MainActivity.kt` | Native Android SMS |
| `pubspec.yaml` | Dependencies |

---

## 🤝 Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature/new-feature`
3. Follow the patterns in this guide
4. Test thoroughly
5. Submit pull request

---

## 📞 Support

**Lwena TechWareAfrica**
- GitHub: [@LWENA27](https://github.com/LWENA27)
- Issues: [GitHub Issues](https://github.com/LWENA27/sms_getway/issues)

---

*Last Updated: December 2024*
