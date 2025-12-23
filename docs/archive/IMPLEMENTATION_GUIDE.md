## SMS Gateway - Implementation Guide

This guide provides step-by-step instructions for implementing the SMS Gateway system.

---

## 📋 Phase 1: MVP Setup

### Step 1: Flutter Project Setup

```bash
# Create Flutter project
flutter create sms_gateway

# Navigate to project
cd sms_gateway

# Add dependencies to pubspec.yaml
flutter pub add supabase_flutter
flutter pub add flutter_svg
flutter pub add shared_preferences
flutter pub add intl
flutter pub add csv
flutter pub add permission_handler
flutter pub add uni_links
```

### Step 2: Supabase Configuration

1. **Create Supabase Project:**
   - Go to [supabase.com](https://supabase.com)
   - Sign up and create a new project
   - Wait for database to be ready

2. **Get Credentials:**
   - Go to Settings → API
   - Copy `Project URL` and `anon key`

3. **Update Constants:**
   ```dart
   // lib/core/constants.dart
   static const String supabaseUrl = 'YOUR_URL_HERE';
   static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
   ```

4. **Create Tables:**
   - Copy content from `database/schema.sql`
   - Go to Supabase Dashboard → SQL Editor
   - Create new query and paste the SQL
   - Run query

5. **Enable Authentication:**
   - Go to Authentication → Providers
   - Enable Email provider
   - Configure email settings

### Step 3: Main App Setup

Create `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: LoginScreen(),
    );
  }
}
```

### Step 4: Create Screen Files

Create the following files with basic widget structure:

**`lib/auth/login_screen.dart`**
```dart
import 'package:flutter/material.dart';
import '../core/theme.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('SMS Gateway')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.paddingLarge),
        child: Column(
          children: [
            SizedBox(height: 50),
            Text(
              'SMS Gateway',
              style: Theme.of(context).textTheme.displaySmall,
            ),
            SizedBox(height: 50),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: isLoading ? null : _login,
              child: isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(),
                    )
                  : Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  void _login() {
    // TODO: Implement login logic
    print('Login tapped');
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
```

Create similar screen files:
- `lib/auth/register_screen.dart`
- `lib/contacts/add_contact.dart`
- `lib/contacts/import_contacts.dart`
- `lib/groups/group_screen.dart`
- `lib/sms/bulk_sms_screen.dart`
- `lib/sms/sms_logs.dart`
- `lib/settings/profile.dart`

### Step 5: Implement Authentication Service

Create `lib/api/auth_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/user_model.dart';

class AuthService {
  static final supabase = Supabase.instance.client;

  static Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      
      if (response.user == null) throw Exception('Sign up failed');
      
      return User(
        id: response.user!.id,
        email: email,
        name: name,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Sign up error: $e');
      rethrow;
    }
  }

  static Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user == null) throw Exception('Login failed');
      
      return User(
        id: response.user!.id,
        email: email,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    await supabase.auth.signOut();
  }

  static User? get currentUser {
    final authUser = supabase.auth.currentUser;
    if (authUser == null) return null;
    
    return User(
      id: authUser.id,
      email: authUser.email ?? '',
      createdAt: DateTime.now(),
    );
  }

  static Stream<AuthState> get authStateChanges {
    return supabase.auth.onAuthStateChange;
  }
}
```

---

## 📱 Phase 1 Features Implementation

### Feature 1: Contact Management

**Add Contact:**
```dart
Future<void> addContact(String name, String phoneNumber) async {
  // Validate
  if (!SmsSenderService.validatePhoneNumber(phoneNumber)) {
    throw Exception('Invalid phone number');
  }
  
  // Insert to database
  await Supabase.instance.client
      .from('contacts')
      .insert({
        'user_id': userId,
        'name': name,
        'phone_number': phoneNumber,
      });
}
```

**Import Contacts from CSV:**
```dart
Future<void> importFromCsv(File csvFile) async {
  // Read CSV file
  final csv = await csvFile.readAsString();
  final rows = const CsvToListConverter().convert(csv);
  
  // Insert each contact
  for (var row in rows.skip(1)) {
    await addContact(row[0], row[1]);
  }
}
```

### Feature 2: Send Bulk SMS

```dart
Future<void> sendBulkSms(
  List<String> recipientPhones,
  String message,
  String senderId,
) async {
  // Validate message
  if (!SmsSenderService.validateMessage(message)) {
    throw Exception('Invalid message');
  }
  
  // Send to each recipient
  for (final phone in recipientPhones) {
    try {
      // Log as pending
      await Supabase.instance.client
          .from('sms_logs')
          .insert({
            'user_id': userId,
            'sender': senderId,
            'recipient': phone,
            'message': message,
            'status': 'pending',
          });
      
      // Send SMS
      final success = await SmsSenderService.sendSms(
        phoneNumber: phone,
        message: message,
      );
      
      // Update status
      await Supabase.instance.client
          .from('sms_logs')
          .update({'status': success ? 'sent' : 'failed'})
          .eq('recipient', phone)
          .eq('user_id', userId);
    } catch (e) {
      print('Error sending to $phone: $e');
    }
  }
}
```

---

## 🔐 Security Implementation

### Rate Limiting

```dart
class RateLimiter {
  static const maxSmsPerMinute = 30;
  static const maxSmsPerDay = 500;
  
  static Future<bool> canSendSms(String userId) async {
    final now = DateTime.now();
    
    // Check last minute
    final lastMin = await Supabase.instance.client
        .from('sms_logs')
        .select('COUNT() as count')
        .eq('user_id', userId)
        .gte('created_at', now.subtract(Duration(minutes: 1)).toIso8601String());
    
    final countLastMin = (lastMin[0]['count'] ?? 0) as int;
    if (countLastMin >= maxSmsPerMinute) return false;
    
    // Check today
    final today = now.copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    final dailyCount = await Supabase.instance.client
        .from('sms_logs')
        .select('COUNT() as count')
        .eq('user_id', userId)
        .gte('created_at', today.toIso8601String());
    
    final countToday = (dailyCount[0]['count'] ?? 0) as int;
    return countToday < maxSmsPerDay;
  }
}
```

---

## 🧪 Testing

Run tests:
```bash
flutter test
```

Build APK:
```bash
flutter build apk --release
```

---

## 🐛 Troubleshooting

### Supabase Connection Error
- Check URL and Anon Key in constants.dart
- Verify internet connection
- Check Supabase project status

### SMS Not Sending
- Ensure device has SMS capability
- Check permissions are granted
- Verify phone number format

---

## 📚 Next Steps

1. Complete Phase 1 with all features
2. Add proper error handling and UI feedback
3. Implement comprehensive testing
4. Create admin dashboard
5. Start Phase 2: Backend API integration

---

**Last Updated:** December 22, 2025
