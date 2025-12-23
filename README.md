# SMS Gateway Pro# 📱 SMS Gateway# SMS Gateway - Complete Project Documentation



Professional Bulk SMS Management System built with Flutter and Supabase.



## 🚀 FeaturesA professional multi-tenant SMS gateway application for bulk messaging with enterprise-grade features.## 🎯 PROJECT OVERVIEW



- **Contact Management**: Add, edit, and organize your contactsA comprehensive SMS gateway application built with Flutter (mobile) and backend services. Enables bulk SMS sending through Android phones, REST API integration, and professional SMS provider integration.

- **Group Management**: Create groups and manage member lists

- **Bulk SMS**: Send messages to multiple contacts or groups## ✨ Features

- **SMS Logs**: Track all sent messages with delivery status

- **Multi-tenant Architecture**: Secure, isolated data per organization---

- **User Authentication**: Secure login with Supabase Auth

- **Row-Level Security**: Data access controlled by user permissions- 🔐 **Multi-Tenant Architecture** - Complete workspace isolation



## 📱 Screenshots- 👥 **Contact Management** - Organize contacts and groups## 🪜 DEVELOPMENT PHASES



[Add screenshots here]- 📤 **Bulk SMS Sending** - Send messages to multiple recipients



## 🛠️ Tech Stack- 📊 **SMS Logs & Analytics** - Track delivery status and history### 🔹 PHASE 1: MVP (Phone-based SMS Gateway)



- **Frontend**: Flutter (Dart)- 🔑 **API Key Management** - Secure API authentication

- **Backend**: Supabase (PostgreSQL + Auth + Real-time)

- **Architecture**: Multi-tenant SaaS with schema isolation- 📱 **Android Native** - Direct SIM card integration**Goal:** Make it work with ZERO experience

- **Platform**: Android (iOS support coming soon)

- 🎨 **Modern UI** - Clean and intuitive interface

## 📋 Prerequisites

**Features:**

- Flutter SDK (3.0+)

- Android Studio or VS Code## 🚀 Quick Start- ✅ Login / Authentication

- Supabase Account

- Git- ✅ Add contacts (manual / CSV import)



## 🔧 Setup Instructions### Prerequisites- ✅ Create groups (member management)



### 1. Clone the Repository- ✅ Send bulk SMS using phone SIM



```bash- Flutter 3.0+- ✅ SMS logs (sent / failed tracking)

git clone https://github.com/LWENA27/sms_getway.git

cd sms_getway- Android Studio / Xcode

```

- Supabase account**How SMS works (Phase 1):**

### 2. Install Dependencies

- Android device (for SMS sending)```

```bash

flutter pub getUser → App → Android Phone SIM → SMS sent

```

### Installation```

### 3. Configure Supabase



1. Create a project at [supabase.com](https://supabase.com)

2. Copy your project URL and anon key```bash**⚠️ Limitation:**

3. Update `lib/core/constants.dart`:

# Clone the repository- Only Android can send SMS directly

```dart

static const supabaseUrl = 'YOUR_SUPABASE_URL';git clone https://github.com/LWENA27/sms_getway.git- iOS will be UI-only (cannot auto-send SMS)

static const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

```cd sms_getway- ✅ This is OK for MVP



### 4. Set Up Database



Run the migration scripts in your Supabase SQL Editor:# Install dependencies---



1. Go to: `https://supabase.com/dashboard/project/YOUR_PROJECT/sql/new`flutter pub get

2. Run `database/sample_test_data.sql` to create tables and sample data

3. Configure API access (see Database Setup below)### 🔹 PHASE 2: Backend Integration



### 5. Database Setup (Important!)# Run the app



#### Enable Schema Access:flutter run**Goal:** Make it usable by other systems



1. Run SQL to grant permissions:```



```sql**Features:**

-- Grant usage on schema

GRANT USAGE ON SCHEMA sms_gateway TO anon, authenticated;### Configuration- API keys management

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sms_gateway TO authenticated;

```- REST API endpoints



2. Go to: `Settings → API → Exposed schemas`1. Copy `.env.example` to `.env`- External systems integration

3. Add `sms_gateway` to the list: `public, graphql_public, sms_gateway`

4. Click **Save**2. Add your Supabase credentials:



#### Enable Row-Level Security:   ```**Flow:**



Run the RLS policies script (see `docs/DATABASE_STATUS.md` for details).   SUPABASE_URL=your_supabase_url```



### 6. Run the App   SUPABASE_ANON_KEY=your_anon_keySchool System → Your API → Mobile Gateway → SMS



```bash   ``````

flutter run

```



## 📚 Documentation## 📖 Documentation---



- [Architecture Guide](docs/ARCHITECTURE.md) - System design and database schema

- [API Reference](docs/API.md) - REST API endpoints and examples

- [Deployment Guide](docs/DEPLOYMENT.md) - Production deployment instructions- [Architecture](docs/ARCHITECTURE.md) - System design and structure### 🔹 PHASE 3: Sender ID (Professional Level)

- [Database Status](docs/DATABASE_STATUS.md) - Database setup and RLS policies

- [API Documentation](docs/API.md) - REST API reference

## 🔐 Security

- [Deployment](docs/DEPLOYMENT.md) - Production deployment guide**Goal:** Business-grade SMS

- **Authentication**: Email/password via Supabase Auth

- **Authorization**: Row-Level Security (RLS) policies

- **Data Isolation**: Multi-tenant schema with user_id filtering

- **API Security**: JWT tokens, anon key protection## 🏗️ Architecture**Features:**



## 📖 Usage- SMS provider integration (Africa's Talking, Twilio, Beem, etc.)



1. **Login**: Use your Supabase account credentials```- Sender ID approval flow

2. **Add Contacts**: Navigate to Contacts → Add Contact

3. **Create Groups**: Go to Groups → Create Group → Add Members┌─────────────────┐- Credits system

4. **Send SMS**: Bulk SMS → Select recipients → Compose → Send

5. **View Logs**: Check SMS Logs for delivery status│   Flutter App   │- Professional branding



## 🐛 Known Issues│  (Multi-Tenant) │



- SMS sending requires Android platform channel implementation└────────┬────────┘**Flow:**

- iOS support not yet available

- Real-time updates not yet implemented         │```



## 🚀 Roadmap         ▼System → API → SMS Provider → Users (Sender: "LWENATECH")



- [ ] Implement actual SMS sending via Android platform channel┌─────────────────┐```

- [ ] Add iOS support

- [ ] Real-time message status updates│    Supabase     │

- [ ] Schedule SMS for future delivery

- [ ] SMS templates│  (PostgreSQL)   │---

- [ ] Contact import/export

- [ ] Analytics dashboard└────────┬────────┘

- [ ] Dark mode

         │## 📱 MOBILE APP STRUCTURE (Flutter)

## 🤝 Contributing

         ▼

Contributions are welcome! Please follow these steps:

┌─────────────────┐```

1. Fork the repository

2. Create a feature branch: `git checkout -b feature/amazing-feature`│  Android Device │lib/

3. Commit your changes: `git commit -m 'Add amazing feature'`

4. Push to the branch: `git push origin feature/amazing-feature`│   (SMS Sender)  ││

5. Open a Pull Request

└─────────────────┘├── main.dart

## 📄 License

```├── core/

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

│   ├── constants.dart

## 👨‍💻 Author

### Database Schema│   ├── theme.dart

**LWENA27**

│

- GitHub: [@LWENA27](https://github.com/LWENA27)

- **public** - Control plane (clients, users, access control)├── auth/

## 🙏 Acknowledgments

- **sms_gateway** - Application data (contacts, groups, logs)│   ├── login_screen.dart

- [Flutter](https://flutter.dev) - UI framework

- [Supabase](https://supabase.com) - Backend and database- **auth** - Supabase authentication│   ├── register_screen.dart

- [Material Design](https://material.io) - Design system

│

## 📞 Support

## 🛠️ Development├── contacts/

For support, email or open an issue in the GitHub repository.

│   ├── contact_model.dart

---

### Project Structure│   ├── add_contact.dart

Made with ❤️ using Flutter and Supabase

│   ├── import_contacts.dart

```│

lib/├── groups/

├── main.dart              # App entry point│   ├── group_model.dart

├── api/                   # API services│   ├── group_screen.dart

├── auth/                  # Authentication│

├── contacts/              # Contact management├── sms/

├── core/                  # Core utilities│   ├── sms_sender.dart

├── groups/                # Group management│   ├── bulk_sms_screen.dart

├── screens/               # UI screens│   ├── sms_logs.dart

└── sms/                   # SMS functionality│

```├── api/

│   ├── supabase_service.dart

### Run Tests│   ├── sms_api.dart

│

```bash└── settings/

flutter test    ├── profile.dart

```    ├── sender_id.dart

```

### Build for Production

---

```bash

# Android## 🗄️ DATABASE STRUCTURE (Supabase / PostgreSQL)

flutter build apk --release

### users table

# iOS```sql

flutter build ios --releaseCREATE TABLE users (

```  id UUID PRIMARY KEY,

  name VARCHAR(255),

## 📝 License  email VARCHAR(255) UNIQUE,

  role VARCHAR(50),

This project is licensed under the MIT License.  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);

## 👥 Contributors```



- [LWENA27](https://github.com/LWENA27)### contacts table

```sql

## 🤝 ContributingCREATE TABLE contacts (

  id UUID PRIMARY KEY,

Contributions are welcome! Please feel free to submit a Pull Request.  user_id UUID REFERENCES users(id),

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
