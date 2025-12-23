# SMS Gateway - Complete Project Documentation

## 🎯 PROJECT OVERVIEW
A comprehensive SMS gateway application built with Flutter (mobile) and backend services. Enables bulk SMS sending through Android phones, REST API integration, and professional SMS provider integration.

---

## 🪜 DEVELOPMENT PHASES

### 🔹 PHASE 1: MVP (Phone-based SMS Gateway)

**Goal:** Make it work with ZERO experience

**Features:**
- ✅ Login / Authentication
- ✅ Add contacts (manual / CSV import)
- ✅ Create groups (member management)
- ✅ Send bulk SMS using phone SIM
- ✅ SMS logs (sent / failed tracking)

**How SMS works (Phase 1):**
```
User → App → Android Phone SIM → SMS sent
```

**⚠️ Limitation:**
- Only Android can send SMS directly
- iOS will be UI-only (cannot auto-send SMS)
- ✅ This is OK for MVP

---

### 🔹 PHASE 2: Backend Integration

**Goal:** Make it usable by other systems

**Features:**
- API keys management
- REST API endpoints
- External systems integration

**Flow:**
```
School System → Your API → Mobile Gateway → SMS
```

---

### 🔹 PHASE 3: Sender ID (Professional Level)

**Goal:** Business-grade SMS

**Features:**
- SMS provider integration (Africa's Talking, Twilio, Beem, etc.)
- Sender ID approval flow
- Credits system
- Professional branding

**Flow:**
```
System → API → SMS Provider → Users (Sender: "LWENATECH")
```

---

## 📱 MOBILE APP STRUCTURE (Flutter)

```
lib/
│
├── main.dart
├── core/
│   ├── constants.dart
│   ├── theme.dart
│
├── auth/
│   ├── login_screen.dart
│   ├── register_screen.dart
│
├── contacts/
│   ├── contact_model.dart
│   ├── add_contact.dart
│   ├── import_contacts.dart
│
├── groups/
│   ├── group_model.dart
│   ├── group_screen.dart
│
├── sms/
│   ├── sms_sender.dart
│   ├── bulk_sms_screen.dart
│   ├── sms_logs.dart
│
├── api/
│   ├── supabase_service.dart
│   ├── sms_api.dart
│
└── settings/
    ├── profile.dart
    ├── sender_id.dart
```

---

## 🗄️ DATABASE STRUCTURE (Supabase / PostgreSQL)

### users table
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  name VARCHAR(255),
  email VARCHAR(255) UNIQUE,
  role VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### contacts table
```sql
CREATE TABLE contacts (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  phone_number VARCHAR(20),
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### groups table
```sql
CREATE TABLE groups (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  group_name VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### group_members table
```sql
CREATE TABLE group_members (
  id UUID PRIMARY KEY,
  group_id UUID REFERENCES groups(id),
  contact_id UUID REFERENCES contacts(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### sms_logs table
```sql
CREATE TABLE sms_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  sender VARCHAR(255),
  message TEXT,
  recipient VARCHAR(20),
  status VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### api_keys table (Phase 2)
```sql
CREATE TABLE api_keys (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  key VARCHAR(255) UNIQUE,
  status VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 🔐 SECURITY CONSIDERATIONS

- ✅ Rate limiting (prevent spam)
- ✅ Message length limit (160 characters for single SMS)
- ✅ Daily SMS quota per user
- ✅ Phone verification (Phase 2)
- ✅ API key validation
- ✅ User authentication & authorization
- ✅ Data encryption in transit
- ✅ Row-level security in database

---

## 🚨 LEGAL & POLICY NOTES (CRITICAL)

Sending bulk SMS requires:

1. **User Consent** - Always obtain explicit user consent before sending
2. **Opt-out Support** - Implement STOP command handling
3. **Sender ID Approval** - Required for professional use
4. **Terms & Privacy** - Clear terms of service and privacy policy
5. **Rate Limiting** - Prevent abuse and compliance violations

⚠️ **WARNING:** Ignoring these can get SIMs blocked and result in legal issues.

---

## 🚀 TECH STACK

| Component | Technology |
|-----------|-----------|
| Mobile | Flutter |
| Backend | Node.js / Python / Django |
| Database | Supabase (PostgreSQL) |
| Authentication | Supabase Auth |
| API | REST API |
| SMS (Phase 1) | Native Android SMS API |
| SMS (Phase 3) | Africa's Talking / Twilio / Beem |

---

## 📋 GETTING STARTED

### Prerequisites
- Flutter SDK (latest)
- Supabase account
- Android device/emulator (for Phase 1)
- Node.js / Python (for backend in Phase 2)

### Installation
```bash
# Clone repository
git clone <repo-url>

# Navigate to project
cd sms_gateway

# Install Flutter dependencies
flutter pub get

# Run app
flutter run
```

---

## 🔄 DEVELOPMENT ROADMAP

- [ ] Phase 1: MVP with local Android SMS
- [ ] Phase 2: Backend API & external integrations
- [ ] Phase 3: Professional SMS provider setup
- [ ] Documentation & deployment
- [ ] Testing & QA

---

## 📞 SUPPORT & CONTACT

For questions or issues, please refer to documentation or contact the development team.

---

**Last Updated:** December 22, 2025
