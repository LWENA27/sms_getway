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
│  ├── 2.2 Backend & Sync Layer                       🔲 Next Up          │
│  ├── 2.3 API-Triggered SMS                          🔲 Planned          │
│  ├── 2.4 API Security & Control                     🔲 Planned          │
│  └── 2.5 Provider / Sender ID Integration           🔲 Planned          │
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

## 🔄 Phase 2: Connected & API-Enabled Gateway (IN PROGRESS)

**Goal:** Enable organizations to send SMS via UI or external systems, sync logs online, and prepare for Sender ID integration.

---

### 🔸 Phase 2.1 – Organization & Authentication ✅ COMPLETE

**Objective:** Introduce organization-level ownership and secure access.

| Feature | Status | Description |
|---------|--------|-------------|
| Organization Registration | ✅ | Company/school signup via Supabase |
| Secure Login | ✅ | Email/password authentication |
| Multi-Tenant Access | ✅ | Users can belong to multiple orgs |
| Workspace Picker | ✅ | Select organization after login |
| Tenant-Scoped Data | ✅ | All data filtered by tenant_id |
| Session Management | ✅ | Secure token handling |
| Role System | ✅ | Owner, Admin, Member, Viewer roles |

**Architecture:**
```
User Login → Load Tenants → (2+ tenants?) → Workspace Picker → Home
                              ↓ (1 tenant)
                         Auto-select → Home
```

📌 **Status:** Completed December 2024

---

### 🔸 Phase 2.2 – Backend & Sync Layer

**Objective:** Centralize message logging and enable offline-to-online sync.

| Feature | Status | Description |
|---------|--------|-------------|
| Central Message Storage | 🔲 | PostgreSQL via Supabase |
| Sync Sent/Failed SMS | 🔲 | Upload logs when online |
| Timestamping | 🔲 | Accurate message timing |
| Message Source Tracking | 🔲 | Track origin: UI, API, Provider |

**Sync Behavior:**
```
┌─────────────────────────────────────────────────────────────┐
│  OFFLINE: SMS sent → Stored locally                        │
│  ONLINE:  Local logs → Synced to Supabase                  │
└─────────────────────────────────────────────────────────────┘
```

📌 Manual SMS can sync **later** when internet is available.

---

### 🔸 Phase 2.3 – API-Triggered SMS (Online Only)

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

**API Endpoints (Planned):**

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/sms/send` | Send single SMS |
| `POST` | `/api/sms/bulk` | Send bulk SMS |
| `GET` | `/api/sms/logs` | Get SMS history |
| `GET` | `/api/sms/status/:id` | Get delivery status |
| `POST` | `/api/contacts` | Create contact |
| `GET` | `/api/contacts` | List contacts |
| `POST` | `/api/groups` | Create group |
| `GET` | `/api/groups` | List groups |

**Requirements:**
- ✅ Active internet connection
- ✅ Valid API key
- ✅ Device online with app running (foreground/background)

📌 API-triggered SMS **cannot work offline** – SMS delivery still uses phone's SIM.

---

### 🔸 Phase 2.4 – API Security & Control

**Objective:** Prevent misuse and unauthorized SMS sending.

| Feature | Status | Description |
|---------|--------|-------------|
| API Key Generation | 🔲 | Per-organization keys |
| Key Rotation | 🔲 | Revoke & regenerate |
| Request Authentication | 🔲 | Bearer token validation |
| Rate Limiting | 🔲 | Prevent abuse |
| Device Authorization | 🔲 | Verify registered device |
| Message Ownership | 🔲 | Tenant isolation |
| Audit Logging | 🔲 | Track all API calls |

**Authentication:**
```http
POST /api/sms/send
Authorization: Bearer sk_live_xxx
X-Tenant-ID: org_uuid_xxx
Content-Type: application/json
```

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

## 📋 Phase 3: Scale & Enterprise Features (PLANNED)

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
| **2.1** | Organization & Auth | Q1 2025 | 🔲 Planned |
| **2.2** | Backend & Sync | Q1 2025 | 🔲 Planned |
| **2.3** | API-Triggered SMS | Q1 2025 | 🔲 Planned |
| **2.4** | API Security | Q2 2025 | 🔲 Planned |
| **2.5** | Sender ID | Q2 2025 | 🔲 Planned |
| **3.0** | Enterprise Features | Q3 2025 | 📋 Planned |

---

## 🎯 Feature Backlog

### 🔴 High Priority (Phase 2)

| Feature | Sub-Phase | Status |
|---------|-----------|--------|
| Organization Registration | 2.1 | 🔲 |
| Secure Authentication | 2.1 | 🔲 |
| Device Binding | 2.1 | 🔲 |
| Message Sync to Cloud | 2.2 | 🔲 |
| API Key Generation | 2.4 | 🔲 |
| REST API Endpoints | 2.3 | 🔲 |
| Rate Limiting | 2.4 | 🔲 |

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

### ✅ Current (Phase 1)

- ✅ Supabase Auth (email/password)
- ✅ Row Level Security (RLS)
- ✅ Tenant Isolation
- ✅ HTTPS/TLS encryption

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

*Last Updated: December 2025*
