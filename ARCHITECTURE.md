## SMS Gateway - Architecture & Design Document

---

## 🏗️ System Architecture

### High-Level Overview

```
┌─────────────────────────────────────────────────────────┐
│              Mobile App (Flutter)                       │
│  ┌────────────────────────────────────────────────────┐ │
│  │            Presentation Layer (UI)                │ │
│  │  - Login/Register Screens                         │ │
│  │  - Contact Management UI                          │ │
│  │  - Group Management UI                            │ │
│  │  - Bulk SMS Sending UI                            │ │
│  │  - SMS Logs UI                                    │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │         Business Logic Layer (Services)           │ │
│  │  - AuthService                                    │ │
│  │  - ContactService                                 │ │
│  │  - GroupService                                   │ │
│  │  - SmsService                                     │ │
│  │  - SmsLogService                                  │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │        Data Layer (Models & Local Storage)        │ │
│  │  - Contact, Group, SmsLog Models                  │ │
│  │  - SharedPreferences for caching                  │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          │
                          │ REST API
                          ▼
┌─────────────────────────────────────────────────────────┐
│         Backend (Supabase - PostgreSQL)                │
│  ┌────────────────────────────────────────────────────┐ │
│  │              API Layer                            │ │
│  │  - Authentication API                            │ │
│  │  - CRUD Operations                               │ │
│  │  - Business Logic Functions                      │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │          Database Layer (PostgreSQL)             │ │
│  │  - Users Table                                   │ │
│  │  - Contacts Table                                │ │
│  │  - Groups Table                                  │ │
│  │  - SMS Logs Table                                │ │
│  │  - Audit Logs Table                              │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Native Plugin (Android)
                          ▼
┌─────────────────────────────────────────────────────────┐
│           SMS Engine (Android Native)                  │
│  - SmsManager (sendTextMessage)                       │
│  - SMS Broadcast Receivers                           │
│  - Delivery Reports                                  │ 
└─────────────────────────────────────────────────────────┘
```

---

## 📁 Project Structure (Detailed)

```
sms_gateway/
│
├── lib/
│   │
│   ├── main.dart                          # App entry point
│   │
│   ├── core/                              # Core utilities & configuration
│   │   ├── constants.dart                 # App constants & configuration
│   │   ├── theme.dart                     # App theme & styling
│   │   └── exceptions.dart                # Custom exceptions (TODO)
│   │
│   ├── auth/                              # Authentication module
│   │   ├── user_model.dart                # User data model
│   │   ├── login_screen.dart              # Login UI
│   │   ├── register_screen.dart           # Registration UI
│   │   └── auth_service.dart              # Auth business logic
│   │
│   ├── contacts/                          # Contacts module
│   │   ├── contact_model.dart             # Contact data model
│   │   ├── add_contact.dart               # Add contact screen
│   │   ├── import_contacts.dart           # CSV import screen
│   │   ├── contact_list.dart              # Contact list UI (TODO)
│   │   └── contact_service.dart           # Contact business logic (TODO)
│   │
│   ├── groups/                            # Groups module
│   │   ├── group_model.dart               # Group data models
│   │   ├── group_screen.dart              # Group management UI
│   │   ├── group_service.dart             # Group business logic (TODO)
│   │   └── create_group.dart              # Create group screen (TODO)
│   │
│   ├── sms/                               # SMS module
│   │   ├── sms_log_model.dart             # SMS log data model
│   │   ├── sms_sender.dart                # SMS sending service
│   │   ├── bulk_sms_screen.dart           # Bulk SMS sending UI
│   │   ├── sms_logs.dart                  # SMS logs/history UI
│   │   └── sms_service.dart               # SMS business logic (TODO)
│   │
│   ├── api/                               # API & backend integration
│   │   ├── supabase_service.dart          # Supabase API service
│   │   ├── auth_service.dart              # Authentication service
│   │   └── rate_limiter.dart              # Rate limiting service (TODO)
│   │
│   └── settings/                          # Settings & user profile
│       ├── profile.dart                   # User profile screen
│       ├── sender_id.dart                 # Sender ID settings (Phase 3)
│       └── settings_service.dart          # Settings management (TODO)
│
├── database/
│   ├── schema.sql                         # Database schema & migrations
│   └── migrations/                        # Migration files (TODO)
│
├── backend/                               # Backend for Phase 2
│   ├── node_js/                           # Node.js backend (TODO)
│   ├── python/                            # Python/Django backend (TODO)
│   └── api_docs.md                        # API documentation (TODO)
│
├── test/                                  # Unit & integration tests (TODO)
│   ├── unit/
│   │   ├── contact_test.dart
│   │   ├── group_test.dart
│   │   └── sms_service_test.dart
│   └── integration/
│       └── app_test.dart
│
├── assets/                                # App assets
│   ├── images/
│   ├── icons/
│   └── animations/
│
├── pubspec.yaml                           # Flutter dependencies
├── pubspec.lock                           # Dependency lock file
│
├── android/                               # Android native code
│   ├── app/
│   │   ├── src/main/kotlin/...           # Kotlin SMS service
│   │   └── src/main/AndroidManifest.xml  # Permissions & config
│   └── gradle.properties
│
├── ios/                                   # iOS (UI-only in Phase 1)
│   └── Runner/
│
├── README.md                              # Project overview
├── IMPLEMENTATION_GUIDE.md                # Implementation guide
├── ARCHITECTURE.md                        # This file
└── .gitignore                            # Git ignore patterns
```

---

## 🔄 Data Flow Diagrams

### Authentication Flow

```
User Input (Email, Password)
         │
         ▼
  AuthService.login()
         │
         ▼
  Supabase Auth API
         │
         ▼
  ┌─────────────────┐
  │  Valid Creds?   │
  └─────────────────┘
    /          \
  Yes          No
  │            │
  ▼            ▼
Create JWT   Show Error
User Session
  │
  ▼
Navigate to Home
```

### Send Bulk SMS Flow

```
User: Select Recipients + Type Message
         │
         ▼
SmsSendingScreen: Validate inputs
         │
         ▼
RateLimiter: Check quota
         │
         ├─ Over quota?
         │  └─ Show Error
         │
         └─ OK
            │
            ▼
   Log SMS status: "pending"
            │
            ▼
   SmsSenderService.sendSms()
            │
            ├─ Split message (if > 160 chars)
            │
            ├─ Format phone number
            │
            ├─ Android Native SMS API
            │
            └─ ┌────────────────────┐
               │  Send Successful?  │
               └────────────────────┘
                 /           \
                Yes          No
                │             │
                ▼             ▼
            Update:       Update:
            status=sent   status=failed
                │             │
                └─────┬───────┘
                      │
                      ▼
                Show result to user
```

### Sync Contacts Flow

```
User: Import CSV / Add Contact
         │
         ▼
Validate Phone Number
         │
         ├─ Invalid? → Show Error
         │
         └─ Valid
            │
            ▼
    ContactService.addContact()
            │
            ▼
    Supabase: INSERT into contacts
            │
            ├─ Duplicate? → Show Error
            │
            └─ Success
               │
               ▼
        Update UI with new contact
        Cache locally (SharedPreferences)
```

---

## 🔐 Security Architecture

### Authentication
- **Method:** JWT tokens via Supabase Auth
- **Storage:** Secure token storage (Flutter Secure Storage - TODO)
- **Refresh:** Automatic token refresh on expiry

### Authorization
- **RLS (Row Level Security):** Database-level access control
- **User Isolation:** Users can only access their own data
- **API Keys:** For Phase 2 backend integration

### Data Protection
- **Encryption:** TLS for all API communications
- **Input Validation:** All user inputs validated before processing
- **SQL Injection Prevention:** Using parameterized queries

### Rate Limiting
- **Per Minute:** Max 30 SMS/minute per user
- **Per Day:** Max 500 SMS/day per user
- **Implementation:** Check on app & database level

---

## 📊 Database Schema Overview

### Users Table
```
id: UUID (PK)
email: TEXT (UNIQUE)
name: TEXT
phone_number: TEXT
role: TEXT (user|admin)
created_at: TIMESTAMP
updated_at: TIMESTAMP
```

### Contacts Table
```
id: UUID (PK)
user_id: UUID (FK → users)
name: TEXT
phone_number: TEXT (UNIQUE per user)
created_at: TIMESTAMP
updated_at: TIMESTAMP
```

### Groups Table
```
id: UUID (PK)
user_id: UUID (FK → users)
group_name: TEXT (UNIQUE per user)
description: TEXT
created_at: TIMESTAMP
updated_at: TIMESTAMP
```

### GroupMembers Table
```
id: UUID (PK)
group_id: UUID (FK → groups)
contact_id: UUID (FK → contacts)
added_at: TIMESTAMP
UNIQUE(group_id, contact_id)
```

### SmsLogs Table
```
id: UUID (PK)
user_id: UUID (FK → users)
sender: TEXT
recipient: TEXT
message: TEXT
status: TEXT (sent|failed|delivered|pending)
error_message: TEXT
created_at: TIMESTAMP
updated_at: TIMESTAMP
```

### ApiKeys Table (Phase 2)
```
id: UUID (PK)
user_id: UUID (FK → users)
key: TEXT (UNIQUE)
name: TEXT
status: TEXT (active|inactive|revoked)
last_used_at: TIMESTAMP
created_at: TIMESTAMP
expires_at: TIMESTAMP
```

---

## 🚀 Scalability Considerations

### Phase 1 (MVP)
- Single Android phone as SMS gateway
- Local SQLite for offline support (TODO)
- Direct database access with RLS

### Phase 2 (Scalable)
- Backend API server layer
- API key authentication
- Stateless API design
- Message queue for SMS processing
- Connection pooling

### Phase 3 (Enterprise)
- Multi-SMS provider support
- Load balancing
- Caching layer (Redis)
- Dedicated SMS processing workers
- Analytics & reporting

---

## 📈 Performance Optimization

### Frontend
- Lazy loading for large lists
- Image compression & caching
- State management with Provider/Riverpod (TODO)
- Offline-first architecture (TODO)

### Backend
- Database indexing on frequently queried columns
- Query optimization
- Caching with Supabase realtime (TODO)
- Batch operations for bulk SMS

### Network
- API request batching
- Gzip compression
- Request/response optimization

---

## 🧪 Testing Strategy

### Unit Tests
```
- Model validation tests
- Service logic tests
- Utility function tests
- Rate limiter tests
```

### Integration Tests
```
- Authentication flow
- Contact CRUD operations
- SMS sending flow
- Database interactions
```

### End-to-End Tests
```
- Complete user workflows
- Multi-step operations
- Error handling scenarios
```

### Performance Tests
```
- Bulk SMS sending performance
- Large CSV import
- Database query optimization
```

---

## 📋 Development Timeline

| Phase | Duration | Milestones |
|-------|----------|-----------|
| Phase 1 | 4-6 weeks | Login, Contacts, Groups, SMS, Logs |
| Phase 2 | 6-8 weeks | REST API, External integrations |
| Phase 3 | 6-8 weeks | SMS providers, Sender ID, Credits |

---

## 🔄 CI/CD Pipeline

```
Git Push
  ↓
GitHub Actions
  ├─ Run Tests
  ├─ Code Analysis (Lint)
  ├─ Build APK
  └─ Deploy to Beta Channel (Firebase)
  ↓
Manual Testing
  ↓
Production Release
```

---

## 📞 Support & Maintenance

### Issue Tracking
- GitHub Issues for bugs & features
- Version control with semantic versioning

### Monitoring
- Crash reporting (Firebase Crashlytics - TODO)
- Analytics (Firebase Analytics - TODO)
- User feedback system (TODO)

### Updates
- Regular security updates
- Feature releases (quarterly)
- Bug fixes (as needed)

---

**Last Updated:** December 22, 2025
