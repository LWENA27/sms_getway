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

## 🏗️ Architecture

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
