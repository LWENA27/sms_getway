# 🚀 SMS Gateway Pro - Product Roadmap

A **distributed, SIM-based messaging platform** that allows organizations to send bulk SMS using their **own mobile devices**, with optional internet-based integrations for automation, logging, and Sender ID support.

---

## 🎯 Core Principles

| Principle | Description |
|-----------|-------------|
| **SIM-First Delivery** | Cost-efficient, legal, decentralized SMS via device SIM |
| **Offline-First** | Manual operations work without internet |
| **Online for Automation** | API features require connectivity |
| **Organization-Owned** | Each org uses their own devices and SIM cards |
| **Unified Logging** | All messages logged regardless of delivery channel |
| **Extensible** | Supports future Sender ID and provider integrations |

---

## 📊 Development Phases

```
┌─────────────────────────────────────────────────────────────────────────┐
│  PHASE 1: Local SMS Gateway                         ✅ COMPLETE         │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 2: Connected & API-Enabled Gateway           🔄 IN PROGRESS      │
│  ├── 2.1 Organization & Authentication              ✅ COMPLETE         │
│  ├── 2.2 Backend & Sync Layer                       🔄 IN PROGRESS      │
│  ├── 2.3 API-Triggered SMS                          🔄 PARTIAL          │
│  ├── 2.4 API Security & Control                     🔲 PLANNED          │
│  ├── 2.5 Provider / Sender ID Integration           🔲 PLANNED          │
│  └── 2.6 Settings Backup & Cross-Device Sync        ✅ COMPLETE         │
├─────────────────────────────────────────────────────────────────────────┤
│  PHASE 3: Scale & Enterprise Features               📋 PLANNED          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## ✅ Phase 1: Local SMS Gateway (COMPLETE)

**Goal:** Enable bulk SMS sending directly from a user's phone, working without internet connectivity.

### Features Delivered

| Feature | Status | Description |
|---------|--------|-------------|
| Native Android SMS | ✅ | Send SMS via device SIM card |
| Bulk SMS Sending | ✅ | Send to multiple contacts/groups |
| Contact Management | ✅ | Add, edit, delete, CSV import |
| Group Management | ✅ | Create groups with members |
| Message Composition | ✅ | User-friendly SMS editor |
| Local Message Logs | ✅ | Track sent/failed messages |
| Offline Functionality | ✅ | Works without internet |
| Multi-Tenant Architecture | ✅ | Workspace isolation |
| Dark Mode | ✅ | Full theme support |
| Row Level Security | ✅ | Database-level isolation |

### Architecture
```
User → App UI → Android SmsManager → Phone SIM → Recipient
                     ↓
              Local SQLite Logs
```

### Limitations
- ⚠️ Android only (iOS cannot send SMS programmatically)
- ⚠️ Requires device with active SIM card
- ⚠️ Carrier rate limits may apply
- ⚠️ Sender appears as phone number (not branded)

📌 **Status:** Completed & stable

---

## ✅ Phase 2: Connected & API-Enabled Gateway (MOSTLY COMPLETE)

### 🔸 Phase 2.1 – Organization & Authentication ✅ COMPLETE

**Objective:** Introduce organization-level ownership and secure access.

| Feature | Status | Description |
|---------|--------|-------------|
| Organization Registration | ✅ | Complete 8-step registration flow |
| Secure Login | ✅ | Email/password authentication |
| Multi-Tenant Access | ✅ | Users can belong to multiple orgs |
| Workspace Picker | ✅ | Select organization after login |
| Tenant-Scoped Data | ✅ | All data filtered by tenant_id |
| Session Management | ✅ | Secure token handling |
| Role System | ✅ | Owner, Admin, Member, Viewer roles |
| Client-Product Access | ✅ | Product access verification for login |
| RLS Policies | ✅ | Row-level security on all tables |

**Registration Flow (8 Steps):**
```
1. Create auth.users account
2. Create public.clients record (top-level organization)
3. Create sms_gateway.tenants record (product tenant)
4. Create sms_gateway.users record (user profile)
5. Create sms_gateway.tenant_members record (membership)
6. Create sms_gateway.user_settings record (preferences)
7. Create sms_gateway.tenant_settings record (org config)
8. Create public.client_product_access record (login verification)
```

**Login Architecture:**
```
User Login → Auth → Load Tenants (via client_product_access)
                         ↓
              (2+ tenants?) → Workspace Picker → Home
                         ↓ (1 tenant)
                    Auto-select → Home
```

📌 **Status:** Completed December 28, 2024

---

### 🔸 Phase 2.2 – Backend & Sync Layer 🔄 IN PROGRESS

**Objective:** Centralize message logging and enable offline-to-online sync.

| Feature | Status | Description |
|---------|--------|-------------|
| Central Message Storage | ✅ | PostgreSQL via Supabase |
| SMS Logs Table | ✅ | sms_gateway.sms_logs with delivery tracking |
| Contacts Storage | ✅ | Centralized contact management |
| Groups Storage | ✅ | Group and membership tracking |
| Sync Sent/Failed SMS | � | Partial - logs created on send |
| Timestamping | ✅ | Accurate message timing |
| Message Source Tracking | � | UI tracking implemented |
| Offline-First Storage | 🔲 | Local cache with sync planned |

**Current Sync Behavior:**
```
┌─────────────────────────────────────────────────────────────┐
│  ONLINE: SMS sent → Stored directly to Supabase            │
│  OFFLINE: To be implemented - local queue with sync        │
└─────────────────────────────────────────────────────────────┘
```

📌 Currently requires internet connection. Full offline support planned.

---

### 🔸 Phase 2.3 – API-Triggered SMS (Online Only) 🔄 PARTIAL

**Objective:** Allow external systems (CRMs, ERPs, school systems) to trigger SMS via the mobile app.

**Flow:**
```
External System → Internet → API → Mobile App → SIM → Recipient
        ↓
   POST /api/sms/send
   {
     "api_key": "sk_xxx",
     "recipients": ["+255..."],
     "message": "Your order is ready"
   }
```

**API Implementation Status:**

| Method | Endpoint | Status | Description |
|--------|----------|--------|-------------|
| `POST` | `/api/sms/send` | 🔄 | Queue-based system implemented |
| `POST` | `/api/sms/bulk` | 🔄 | Via queue service |
| `GET` | `/api/sms/logs` | 🔲 | Planned |
| `GET` | `/api/sms/status/:id` | 🔲 | Planned |
| `POST` | `/api/contacts` | 🔲 | Planned |
| `GET` | `/api/contacts` | 🔲 | Planned |
| `POST` | `/api/groups` | 🔲 | Planned |
| `GET` | `/api/groups` | 🔲 | Planned |

**Current Implementation:**
- ✅ API SMS Queue Service (ApiSmsQueueService)
- ✅ Database polling every 30 seconds
- ✅ Support for both Native SMS and QuickSMS API
- ✅ Auto-start queue processing setting
- ✅ Manual queue control in Settings UI
- 🔲 Edge Functions for API endpoints (planned)
- 🔲 API key authentication (planned)

**Requirements:**
- ✅ Active internet connection
- 🔲 Valid API key (to be implemented)
- ✅ Device online with app running
- ✅ Queue processing enabled in settings

📌 API-triggered SMS **cannot work offline** – SMS delivery still uses phone's SIM.

---

### 🔸 Phase 2.4 – API Security & Control 🔲 PLANNED

**Objective:** Prevent misuse and unauthorized SMS sending.

| Feature | Status | Description |
|---------|--------|-------------|
| API Key Generation | 🔲 | Per-organization keys |
| Key Rotation | 🔲 | Revoke & regenerate |
| Request Authentication | 🔲 | Bearer token validation |
| Rate Limiting | 🔲 | Prevent abuse |
| Device Authorization | 🔲 | Verify registered device |
| Message Ownership | ✅ | Tenant isolation via RLS |
| Audit Logging | 🔲 | Track all API calls |
| Edge Functions | 🔲 | Supabase serverless endpoints |

**Planned Authentication:**
```http
POST /api/sms/send
Authorization: Bearer sk_live_xxx
X-Tenant-ID: org_uuid_xxx
Content-Type: application/json
```

**Current Security:**
- ✅ Row Level Security (RLS) on all tables
- ✅ Tenant isolation at database level
- ✅ Supabase Auth for user authentication
- 🔲 API key system (planned)

---

### 🔸 Phase 2.5 – Provider / Sender ID Integration (Optional)

**Objective:** Support internet-based SMS providers for branded Sender ID.

**Use Cases:**
- 🏢 Branded Sender ID (e.g., "MYSCHOOL" instead of phone number)
- 💳 No SIM balance / SIM not available
- 📊 High-volume campaigns
- 📋 Regulatory requirements

**Channel Selection:**

| Channel | Internet | SIM | Sender | Cost |
|---------|----------|-----|--------|------|
| **Manual UI → SIM** | ❌ | ✅ | Phone Number | Carrier rates |
| **API → SIM** | ✅ | ✅ | Phone Number | Carrier rates |
| **API → Provider** | ✅ | ❌ | Sender ID | Provider rates |

**Provider Integration Priority:**
1. **Africa's Talking** (Africa-focused)
2. **Beem Africa** (East Africa)
3. **Twilio** (International)
4. **Custom Webhook** (bring your own provider)

📌 Provider use is **optional**, not mandatory.

---

### � Phase 2.6 – Settings Backup & Cross-Device Sync ✅ COMPLETE

**Objective:** Allow users to backup their settings to Supabase and restore on different devices.

| Feature | Status | Description |
|---------|--------|-------------|
| User Settings Backup | ✅ | SMS channel, theme, language, notifications |
| Tenant Settings Backup | ✅ | Workspace quotas and feature flags |
| Cross-Device Restore | ✅ | Sync preferences across devices |
| Audit Trail | ✅ | Track all backup/restore operations |
| RLS Security | ✅ | User & tenant data isolation |
| UI Integration | ✅ | Backup/restore buttons in Settings |

**Implementation Details:**

Settings backed up include:
- **User Level**: SMS channel (Native/QuickSMS), auto-start queue, theme mode, language, notification preferences
- **Tenant Level**: Default SMS channel, daily/monthly quotas, feature flags (bulk, scheduled, groups, API), plan type

**Service Architecture:**
```
SettingsBackupService (Singleton)
├── backupUserSettings() → SharedPreferences → RPC → user_settings table
├── restoreUserSettings() → RPC → user_settings table → SharedPreferences
├── backupTenantSettings() → SharedPreferences → REST → tenant_settings table
└── restoreTenantSettings() → REST → tenant_settings table → SharedPreferences
```

**Database Tables:**
- `user_settings` - Per-user preferences with unique(user_id, tenant_id)
- `tenant_settings` - Workspace configuration unique per tenant
- `settings_sync_log` - Audit trail of all sync operations

**RLS Policies:**
- Users can only view/update their own settings
- Tenant admins can update workspace settings
- All operations logged for audit trail

**User Flow:**
```
Device A:
1. Configure SMS settings
2. Go to Settings → Backup Settings to Supabase
3. ✅ Settings saved to cloud

Device B:
1. Login with same account
2. Go to Settings → Restore Settings from Supabase
3. ✅ Settings match Device A automatically
```

📌 **Status:** Completed December 24, 2024

---

**Goal:** Enterprise-grade features for large organizations.

| Feature | Description |
|---------|-------------|
| Multi-User Roles | Admin, Manager, Staff with permissions |
| Multiple Devices | One org → multiple gateway phones |
| Delivery Reports | DLR where provider supports |
| Message Templates | Reusable message formats |
| Scheduled SMS | Send at specific time |
| Usage Analytics | Dashboard with charts |
| Billing & Quotas | Credit system, usage limits |
| High-Availability Routing | Failover between providers |

---

## 📱 Platform Support

| Platform | SMS Sending | Dashboard | API Relay | Status |
|----------|-------------|-----------|-----------|--------|
| **Android** | ✅ Full SIM | ✅ | ✅ | Primary |
| **iOS** | ❌ No SIM | ✅ View Only | ✅ | Planned |
| **Web** | ❌ | ✅ Admin | ✅ | Future |

📌 iOS **cannot send SMS programmatically via SIM** (Apple restriction).

---

## 📅 Timeline

| Phase | Milestone | Target | Status |
|-------|-----------|--------|--------|
| **1.0** | Local SMS Gateway | Q4 2024 | ✅ Complete |
| **2.1** | Organization & Auth | Q4 2024 | ✅ Complete |
| **2.2** | Backend & Sync | Q4 2024 | � In Progress |
| **2.3** | API-Triggered SMS | Q1 2025 | � Partial |
| **2.4** | API Security | Q1 2025 | 🔲 Planned |
| **2.5** | Sender ID | Q2 2025 | 🔲 Planned |
| **2.6** | Settings Backup | Q4 2024 | ✅ Complete |
| **3.0** | Enterprise Features | Q3 2025 | 📋 Planned |

---

## 🎯 Feature Backlog

### 🔴 High Priority (Phase 2)

| Feature | Sub-Phase | Status |
|---------|-----------|--------|
| Organization Registration | 2.1 | ✅ Complete |
| Secure Authentication | 2.1 | ✅ Complete |
| Multi-Tenant Access | 2.1 | ✅ Complete |
| Settings Backup/Restore | 2.6 | ✅ Complete |
| Client-Product Access | 2.1 | ✅ Complete |
| Offline-First Storage | 2.2 | � In Progress |
| Message Sync to Cloud | 2.2 | � In Progress |
| REST API Endpoints | 2.3 | 🔲 Planned |
| API Key Generation | 2.4 | 🔲 Planned |
| Rate Limiting | 2.4 | 🔲 Planned |

### 🟡 Medium Priority (Phase 2.5 / 3)

| Feature | Phase | Status |
|---------|-------|--------|
| Sender ID Support | 2.5 | 🔲 |
| Provider Integration | 2.5 | 🔲 |
| Scheduled SMS | 3 | 🔲 |
| Message Templates | 3 | 🔲 |
| Delivery Reports | 3 | 🔲 |
| Analytics Dashboard | 3 | 🔲 |

### 🟢 Low Priority (Future)

| Feature | Phase | Status |
|---------|-------|--------|
| iOS Dashboard | Future | 🔲 |
| Multi-User Roles | 3 | 🔲 |
| Multiple Devices | 3 | 🔲 |
| Two-Way SMS | Future | 🔲 |
| WhatsApp Integration | Future | 🔲 |
| Web Dashboard | Future | 🔲 |

---

## 🛡️ Security Roadmap

### ✅ Current (Phase 1 & 2.1)

- ✅ Supabase Auth (email/password)
- ✅ Row Level Security (RLS) on all tables
- ✅ Tenant Isolation (client_product_access verification)
- ✅ HTTPS/TLS encryption
- ✅ 8-step secure registration flow
- ✅ Session management
- ✅ Multi-tenant access control
- ✅ Settings encryption in SharedPreferences

### 🔲 Planned (Phase 2+)

| Feature | Phase | Priority |
|---------|-------|----------|
| API Key Encryption | 2.4 | High |
| Rate Limiting | 2.4 | High |
| Device Authorization | 2.4 | High |
| Audit Logging | 2.4 | High |
| IP Whitelisting | 3 | Medium |
| Two-Factor Auth (2FA) | 3 | Medium |
| OAuth2 Integration | 3 | Low |

---

## 💼 Business Model (Future)

### Free Tier
- ✅ Unlimited SMS via phone SIM
- ✅ Up to 500 contacts
- ✅ Basic local logs
- ❌ No API access

### Pro Tier
- ✅ Everything in Free
- ✅ API access
- ✅ Cloud sync & logs
- ✅ Unlimited contacts
- ✅ Priority support

### Enterprise Tier
- ✅ Everything in Pro
- ✅ Sender ID support
- ✅ Multiple devices
- ✅ Multi-user roles
- ✅ Custom integrations
- ✅ SLA guarantee

---

## 📣 Request a Feature

Have a feature request?
- Open an issue on [GitHub](https://github.com/LWENA27/sms_getway/issues)
- Label it as `enhancement`
- Describe the use case

---

## 📞 Contact

**Lwena TechWareAfrica**
- GitHub: [@LWENA27](https://github.com/LWENA27)
- Repository: [sms_getway](https://github.com/LWENA27/sms_getway)

---

## 📝 Recent Updates (December 2024)

### December 28, 2024
- ✅ Fixed registration Step 8: Added `client_product_access` record creation
- ✅ Critical fix: Without Step 8, users couldn't login after registration
- ✅ Updated registration to 8-step flow matching remote schema
- ✅ Added RLS policies for `public.clients` and `public.client_product_access`
- ✅ Consolidated documentation, removed 7 redundant markdown files
- ✅ Updated README with complete registration flow and warnings

### December 24, 2024
- ✅ Completed Phase 2.6: Settings Backup & Cross-Device Sync
- ✅ Implemented user and tenant settings backup/restore
- ✅ Added audit trail for all backup/restore operations
- ✅ Created RLS policies for settings tables
- ✅ Added UI controls in Settings screen

### November-December 2024
- ✅ Completed Phase 2.1: Organization & Authentication
- ✅ Implemented complete 8-step registration flow
- ✅ Added multi-tenant architecture with workspace isolation
- ✅ Implemented tenant selector for users with multiple organizations
- ✅ Added auto-select for single-tenant users
- ✅ Created comprehensive RLS policies for data isolation

---

*Last Updated: December 28, 2024*
