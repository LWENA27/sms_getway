# 📲 SMS Gateway Mobile App# sms_getway



A **professional SMS Gateway** mobile application built with Flutter that allows you to send bulk SMS, manage contacts and groups, and integrate with external systems via API.A new Flutter project.



## 🎯 Project Overview## Getting Started



This SMS Gateway app is designed to help businesses, schools, churches, SACCOs, and NGOs in Tanzania send bulk SMS efficiently. The app is built in phases:This project is a starting point for a Flutter application.



- **Phase 1 (MVP):** Phone-based SMS sending using Android SIM card  A few resources to get you started if this is your first Flutter project:

- **Phase 2:** Backend API integration for external systems  

- **Phase 3:** Professional Sender ID support with SMS providers- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)

- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

## ✨ Features

For help getting started with Flutter development, view the

### Current Features (Phase 1 - MVP)[online documentation](https://docs.flutter.dev/), which offers tutorials,

- ✅ User Authentication (Login/Register)samples, guidance on mobile development, and a full API reference.

- ✅ Contact Management (Add, Import CSV, Delete)
- ✅ Group Management (Create groups, Add members)
- ✅ Bulk SMS Sending (Android only)
- ✅ SMS Logs & History
- ✅ SMS Status Tracking (Sent, Failed, Delivered)
- ✅ Rate Limiting & Spam Prevention
- ✅ Professional UI/UX

### Coming Soon (Phase 2 & 3)
- 🔲 REST API for external integrations
- 🔲 API Key management
- 🔲 Sender ID support
- 🔲 SMS Provider integration (Africa's Talking, Twilio, Beem)
- 🔲 Credits system
- 🔲 Scheduled SMS
- 🔲 SMS Templates

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│     Mobile App (Flutter)            │
│  ┌──────────┐  ┌──────────────┐    │
│  │  UI      │  │  Services    │    │
│  │ (Screens)│  │ (Business    │    │
│  │          │  │  Logic)      │    │
│  └──────────┘  └──────────────┘    │
└─────────────────┬───────────────────┘
                  │
                  │ API Calls
                  ▼
┌─────────────────────────────────────┐
│    Backend (Supabase)               │
│  ┌──────────┐  ┌──────────────┐    │
│  │PostgreSQL│  │  Auth        │    │
│  │   DB     │  │  Service     │    │
│  └──────────┘  └──────────────┘    │
└─────────────────┬───────────────────┘
                  │
                  │ SMS Queue
                  ▼
┌─────────────────────────────────────┐
│         SMS Engine                  │
│  Phase 1: Android SIM               │
│  Phase 3: SMS Provider API          │
└─────────────────────────────────────┘
```

## 📁 Project Structure

```
lib/
├── main.dart                   # App entry point
├── core/
│   ├── constants.dart         # App constants & config
│   └── theme.dart             # App theme & styling
├── models/
│   ├── contact.dart           # Contact data model
│   ├── group.dart             # Group & GroupMember models
│   ├── sms_log.dart           # SMS log & status
│   └── user.dart              # User model
├── services/
│   ├── supabase_service.dart  # Backend API service
│   └── sms_sender_service.dart # SMS sending logic
└── screens/
    ├── login_screen.dart      # Login UI
    └── home_page.dart         # Main dashboard
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Android Studio or VS Code
- Android device or emulator (iOS doesn't support SMS sending)
- Supabase account (free tier)

### 1. Install Flutter

If you haven't installed Flutter yet:

```bash
# Download Flutter SDK
# Follow: https://docs.flutter.dev/get-started/install

# Verify installation
flutter doctor
```

### 2. Clone & Setup

```bash
# Navigate to project
cd /media/lwena/LwenaTech2026/projects/sms_getway

# Install dependencies
flutter pub get
```

### 3. Setup Supabase Backend

#### Create Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Copy your **Project URL** and **Anon Key**

#### Update Configuration

Edit `lib/core/constants.dart`:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL_HERE';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
```

#### Create Database Tables

Run these SQL commands in Supabase SQL Editor:

```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email TEXT NOT NULL,
  name TEXT,
  phone_number TEXT,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Contacts table
CREATE TABLE contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Groups table
CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  group_name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Group Members table
CREATE TABLE group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID REFERENCES groups(id) ON DELETE CASCADE,
  contact_id UUID REFERENCES contacts(id) ON DELETE CASCADE,
  added_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(group_id, contact_id)
);

-- SMS Logs table
CREATE TABLE sms_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  sender TEXT NOT NULL,
  recipient TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL,
  error_message TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_contacts_user_id ON contacts(user_id);
CREATE INDEX idx_groups_user_id ON groups(user_id);
CREATE INDEX idx_group_members_group_id ON group_members(group_id);
CREATE INDEX idx_sms_logs_user_id ON sms_logs(user_id);
CREATE INDEX idx_sms_logs_status ON sms_logs(status);
```

#### Enable Row Level Security (RLS)

```sql
-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_logs ENABLE ROW LEVEL SECURITY;

-- Policies for users
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- Policies for contacts
CREATE POLICY "Users can view own contacts" ON contacts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own contacts" ON contacts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own contacts" ON contacts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own contacts" ON contacts
  FOR DELETE USING (auth.uid() = user_id);

-- Policies for groups
CREATE POLICY "Users can view own groups" ON groups
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own groups" ON groups
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own groups" ON groups
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own groups" ON groups
  FOR DELETE USING (auth.uid() = user_id);

-- Policies for group_members
CREATE POLICY "Users can view own group members" ON group_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM groups WHERE groups.id = group_members.group_id AND groups.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can add members to own groups" ON group_members
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM groups WHERE groups.id = group_members.group_id AND groups.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can remove members from own groups" ON group_members
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM groups WHERE groups.id = group_members.group_id AND groups.user_id = auth.uid()
    )
  );

-- Policies for sms_logs
CREATE POLICY "Users can view own SMS logs" ON sms_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own SMS logs" ON sms_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### 4. Run the App

```bash
# Check connected devices
flutter devices

# Run on Android device
flutter run

# Or run in debug mode
flutter run --debug

# Build release APK
flutter build apk --release
```

## 📱 How to Use

### 1. Sign Up
- Open the app
- Click "Don't have an account? Sign Up"
- Enter your details
- Sign in with your credentials

### 2. Add Contacts
- Go to **Contacts** menu
- Click "Add Contact" button
- Enter name and phone number
- Or import from CSV file

### 3. Create Groups
- Go to **Groups** menu
- Create a new group
- Add contacts to the group

### 4. Send SMS
- Go to **Send SMS** menu
- Select recipients (contacts or groups)
- Type your message
- Click "Send"

### 5. View Logs
- Go to **SMS Logs** to see history
- Check status of sent messages

## 🔐 Permissions (Android)

The app requires these permissions:

- `SEND_SMS` - To send SMS messages
- `READ_SMS` - To read SMS status
- `RECEIVE_SMS` - To receive delivery reports
- `READ_PHONE_STATE` - To get phone number
- `INTERNET` - For Supabase connection

⚠️ **Note:** The app will request these permissions at runtime.

## 🐛 Troubleshooting

### App won't build

```bash
flutter clean
flutter pub get
flutter run
```

### Supabase connection errors

- Check your Supabase URL and Key in `constants.dart`
- Verify internet connection
- Check Supabase project status

### SMS not sending

- Ensure you're on a real Android device (not emulator)
- Check SMS permissions are granted
- Verify SIM card is active
- Check phone number format (+255...)

## 🚨 Important Notes

### Legal & Compliance

- ✅ Get user consent before sending SMS
- ✅ Include opt-out instructions (e.g., "Reply STOP to unsubscribe")
- ✅ Respect rate limits to avoid SIM blocking
- ✅ Don't spam - carriers can block your SIM

### Limitations (Phase 1)

- ❌ iOS doesn't support automated SMS sending
- ❌ Limited to phone's SMS bundle
- ❌ No custom Sender ID (shows phone number)
- ❌ Rate limited by carrier (30-50 SMS/minute)

## 🔄 Next Steps

You now have the **foundation** set up! To complete Phase 1, you need to create:

1. **Register Screen** (`lib/screens/register_screen.dart`)
2. **Contacts Screen** (`lib/screens/contacts_screen.dart`)
3. **Groups Screen** (`lib/screens/groups_screen.dart`)
4. **Send SMS Screen** (`lib/screens/send_sms_screen.dart`)
5. **SMS Logs Screen** (`lib/screens/sms_logs_screen.dart`)

These screens will follow the same pattern as `login_screen.dart` and `home_page.dart`.

---

**Built with ❤️ in Tanzania 🇹🇿**

For questions, check the code comments or continue building the remaining screens!
