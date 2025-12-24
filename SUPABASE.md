# 🗄️ Supabase Database Documentation

This document describes the database architecture for SMS Gateway Pro.

---

## 📊 Overview

SMS Gateway uses a **multi-tenant, multi-product SaaS architecture** with PostgreSQL schemas for complete data isolation.

```
┌─────────────────────────────────────────────────────────────┐
│                   SUPABASE DATABASE                          │
├─────────────────────────────────────────────────────────────┤
│  auth.*           │ Supabase built-in authentication        │
├───────────────────┼─────────────────────────────────────────┤
│  public.*         │ Control plane (clients, access control) │
├───────────────────┼─────────────────────────────────────────┤
│  sms_gateway.*    │ SMS Gateway application data            │
└───────────────────┴─────────────────────────────────────────┘
```

---

## 🔑 Connection Details

| Property | Value |
|----------|-------|
| **Project URL** | `https://kzjgdeqfmxkmpmadtbpb.supabase.co` |
| **Project Ref** | `kzjgdeqfmxkmpmadtbpb` |
| **Database Version** | PostgreSQL 15 |
| **Region** | Configured in Supabase Dashboard |

---

## 📁 Schema Structure

### `auth` Schema (Supabase Built-in)
Managed by Supabase - handles user authentication.

| Table | Description |
|-------|-------------|
| `auth.users` | User accounts (email, password hash) |
| `auth.sessions` | Active login sessions |

### `public` Schema (Control Plane)
Manages multi-tenant access control.

| Table | Description |
|-------|-------------|
| `products` | SaaS product catalog |
| `clients` | Organizations/companies |
| `global_users` | All users across products |
| `product_subscriptions` | Client-product relationships |
| `client_product_access` | User permissions per product |
| `product_usage_stats` | Usage metrics |

### `sms_gateway` Schema (Application Data)
SMS Gateway specific tables - **all have `tenant_id` for isolation**.

| Table | Description |
|-------|-------------|
| `users` | User profiles in SMS Gateway |
| `contacts` | Phone contacts |
| `groups` | Contact groups |
| `group_members` | Group membership (many-to-many) |
| `sms_logs` | SMS sending history |
| `api_keys` | API authentication keys |
| `audit_logs` | Activity tracking |
| `settings` | User preferences |

---

## 📋 Table Definitions

### `sms_gateway.users`
```sql
CREATE TABLE sms_gateway.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  email VARCHAR(255),
  name VARCHAR(255),
  phone_number VARCHAR(20),
  role VARCHAR(50) DEFAULT 'user',
  tenant_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.contacts`
```sql
CREATE TABLE sms_gateway.contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tenant_id UUID NOT NULL,
  name VARCHAR(255) NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  email VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.groups`
```sql
CREATE TABLE sms_gateway.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tenant_id UUID NOT NULL,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.group_members`
```sql
CREATE TABLE sms_gateway.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES sms_gateway.groups(id),
  contact_id UUID NOT NULL REFERENCES sms_gateway.contacts(id),
  tenant_id UUID NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(group_id, contact_id)
);
```

### `sms_gateway.sms_logs`
```sql
CREATE TABLE sms_gateway.sms_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tenant_id UUID NOT NULL,
  contact_id UUID REFERENCES sms_gateway.contacts(id),
  phone_number VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  sent_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.api_keys`
```sql
CREATE TABLE sms_gateway.api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  tenant_id UUID NOT NULL,
  key VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255),
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
```

### `sms_gateway.user_settings` (Settings Backup)
```sql
CREATE TABLE sms_gateway.user_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
  
  -- SMS Preferences
  sms_channel TEXT DEFAULT 'thisPhone' CHECK (sms_channel IN ('thisPhone', 'quickSMS')),
  api_queue_auto_start BOOLEAN DEFAULT false,
  
  -- UI Preferences
  theme_mode TEXT DEFAULT 'light' CHECK (theme_mode IN ('light', 'dark', 'system')),
  language TEXT DEFAULT 'en',
  
  -- Notification Preferences
  notification_on_sms_sent BOOLEAN DEFAULT true,
  notification_on_sms_failed BOOLEAN DEFAULT true,
  notification_on_quota_warning BOOLEAN DEFAULT true,
  
  -- Additional settings (JSON for extensibility)
  additional_settings JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  synced_at TIMESTAMP WITH TIME ZONE,
  
  UNIQUE(user_id, tenant_id)
);
```

### `sms_gateway.tenant_settings` (Settings Backup)
```sql
CREATE TABLE sms_gateway.tenant_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL UNIQUE REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
  
  -- Default SMS Settings
  default_sms_channel TEXT DEFAULT 'thisPhone' CHECK (default_sms_channel IN ('thisPhone', 'quickSMS')),
  default_sms_sender_id TEXT,
  
  -- Quota Settings
  daily_sms_quota INTEGER DEFAULT 10000,
  monthly_sms_quota INTEGER DEFAULT 100000,
  
  -- Feature Flags
  enable_bulk_sms BOOLEAN DEFAULT true,
  enable_scheduled_sms BOOLEAN DEFAULT true,
  enable_sms_groups BOOLEAN DEFAULT true,
  enable_api_access BOOLEAN DEFAULT true,
  
  -- API Settings
  api_webhook_url TEXT,
  api_webhook_secret TEXT,
  
  -- Billing & Plan Info
  plan_type TEXT DEFAULT 'basic' CHECK (plan_type IN ('basic', 'pro', 'enterprise')),
  sms_cost_per_unit NUMERIC(10, 4) DEFAULT 0.05,
  
  -- Advanced Settings
  advanced_settings JSONB DEFAULT '{}'::jsonb,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  synced_at TIMESTAMP WITH TIME ZONE,
  
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  updated_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);
```

### `sms_gateway.settings_sync_log` (Settings Backup Audit Trail)
```sql
CREATE TABLE sms_gateway.settings_sync_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES sms_gateway.tenants(id) ON DELETE CASCADE,
  
  sync_type TEXT NOT NULL CHECK (sync_type IN ('user_settings', 'tenant_settings', 'both')),
  direction TEXT NOT NULL CHECK (direction IN ('local_to_remote', 'remote_to_local', 'bidirectional')),
  
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'partial')),
  error_message TEXT,
  
  settings_count INTEGER DEFAULT 0,
  synced_fields TEXT[], -- Array of field names that were synced
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  completed_at TIMESTAMP WITH TIME ZONE
);
```

---

## ⚙️ Settings Backup System

### Overview
The settings backup system allows users to:
- **Backup** their user preferences to Supabase (SMS channel, theme, language, notifications)
- **Backup** tenant-wide settings (quotas, feature flags, plan type)
- **Restore** settings on different devices for cross-device sync
- **Track** all sync operations in audit trail

### How It Works

#### User Settings Backup Flow
1. User clicks "Backup Settings to Supabase" in Settings screen
2. `SettingsBackupService` reads local SharedPreferences
3. Calls RPC function `update_user_settings()` 
4. Creates entry in `settings_sync_log` with status='pending'
5. If successful, marks log entry with status='success'
6. If error, stores error message in log

#### Tenant Settings Backup Flow
1. Tenant admin clicks "Backup Settings to Supabase"
2. `SettingsBackupService` reads tenant settings from SharedPreferences
3. Upserts into `tenant_settings` table via REST API
4. Creates audit log entry in `settings_sync_log`
5. Marks as success/failed based on result

#### Cross-Device Restore Flow
1. User logs in on new device
2. Clicks "Restore Settings from Supabase"
3. `SettingsBackupService` calls `get_user_settings()` RPC
4. Fetches from `user_settings` table
5. Writes all values to local SharedPreferences
6. Logs the restore operation
7. All user preferences now match previous device

### RPC Functions

#### `get_user_settings(p_user_id, p_tenant_id)`
Fetches user settings with RLS applied.
```dart
final response = await supabase.rpc('get_user_settings', params: {
  'p_user_id': userId,
  'p_tenant_id': tenantId,
});
```

#### `update_user_settings(...)`
Upserts user settings (insert if new, update if exists).
```dart
await supabase.rpc('update_user_settings', params: {
  'p_user_id': userId,
  'p_tenant_id': tenantId,
  'p_sms_channel': 'thisPhone',
  'p_api_queue_auto_start': true,
  'p_theme_mode': 'dark',
  'p_language': 'en',
  // ... other settings
});
```

#### `get_tenant_settings(p_tenant_id)`
Fetches tenant settings.

#### `log_settings_sync(...)`
Creates sync log entry for audit trail.

#### `complete_settings_sync(p_log_id, p_status)`
Marks sync operation as completed.

### RLS Policies for Settings Tables

**User Settings:**
- Users can only view their own settings
- Users can only update their own settings
- Tenant members can see settings for their tenant

**Tenant Settings:**
- Tenant members can view settings
- Only admins/owners can update settings
- Prevents regular members from changing workspace config

**Sync Log:**
- Users can view their own sync logs
- Admins can view all sync logs for their tenant
- Complete audit trail of all operations

---

## 🔐 Row Level Security (RLS)

All tables have RLS enabled with policies that enforce:
1. **User Ownership** - Users can only access their own data
2. **Tenant Isolation** - Data is filtered by `tenant_id`
3. **Product Access** - Verified via `client_product_access`

### Example Policy
```sql
-- Users can only view their own contacts in their tenant
CREATE POLICY "Users can view own contacts"
  ON sms_gateway.contacts FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid()
    AND tenant_id IN (
      SELECT tenant_id FROM public.client_product_access
      WHERE user_id = auth.uid()
      AND product_id = (SELECT id FROM public.products WHERE schema_name = 'sms_gateway')
    )
  );
```

---

## 🔄 Multi-Tenant Flow

### Authentication Flow
```
1. User logs in (Supabase Auth)
   ↓
2. Check auth.users (password verification)
   ↓
3. Load public.client_product_access (get tenant list)
   ↓
4. Load sms_gateway.users (product profile)
   ↓
5. If 1 tenant → Auto-select
   If 2+ tenants → Show picker
```

### Query Pattern
```dart
// All queries must include tenant_id
final contacts = await supabase
    .from('sms_gateway.contacts')
    .select()
    .eq('user_id', userId)
    .eq('tenant_id', tenantId);  // Required!
```

---

## 📊 Helper Functions

### `public.create_client`
Creates a new organization/client.
```sql
SELECT public.create_client(
  p_owner_id := 'user-uuid',
  p_client_name := 'My Company',
  p_client_slug := 'my-company',
  p_client_email := 'admin@company.com',
  p_owner_name := 'John Doe',
  p_owner_email := 'john@company.com'
);
```

### `public.subscribe_client_to_product`
Subscribes a client to SMS Gateway and creates a tenant.
```sql
SELECT public.subscribe_client_to_product(
  p_client_id := 'client-uuid',
  p_product_schema := 'sms_gateway',
  p_tenant_name := 'SMS Workspace',
  p_tenant_slug := 'sms-workspace',
  p_plan_type := 'pro'
);
```

### `public.add_user_to_client_product`
Adds a user to a client's product tenant.
```sql
SELECT public.add_user_to_client_product(
  p_user_id := 'user-uuid',
  p_client_id := 'client-uuid',
  p_product_schema := 'sms_gateway',
  p_tenant_id := 'tenant-uuid',
  p_role := 'admin',
  p_user_email := 'user@company.com',
  p_user_name := 'Jane Smith'
);
```

---

## 🛠️ Supabase CLI Commands

### Link to Remote
```bash
npx supabase link --project-ref kzjgdeqfmxkmpmadtbpb
```

### Pull Remote Schema
```bash
npx supabase db pull
```

### Push Migrations
```bash
npx supabase db push
```

### Create New Migration
```bash
npx supabase migration new <migration_name>
```

### List Migrations
```bash
npx supabase migration list
```

---

## 📁 Migration Files

Located in `supabase/migrations/`:

| File | Description |
|------|-------------|
| `20251222223134_remote_schema.sql` | Current production schema |

---

## ⚠️ Important Notes

1. **Schema Prefix Required**
   ```dart
   // ✅ Correct
   .from('sms_gateway.contacts')
   
   // ❌ Wrong
   .from('contacts')
   ```

2. **Always Include tenant_id**
   ```dart
   // ✅ Correct
   .eq('tenant_id', tenantId)
   .eq('user_id', userId)
   ```

3. **Exposed Schemas**
   - In Supabase Dashboard → Settings → API
   - Ensure `sms_gateway` is in exposed schemas list

4. **RLS Must Be Enabled**
   - All tables have RLS enabled by default
   - Never disable RLS in production

---

## 🔍 Verification Queries

### Check Schema Exists
```sql
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name = 'sms_gateway';
```

### Check Tables Have tenant_id
```sql
SELECT table_name, column_name 
FROM information_schema.columns 
WHERE table_schema = 'sms_gateway' 
AND column_name = 'tenant_id';
```

### Check RLS Enabled
```sql
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'sms_gateway';
```

### Check Policies
```sql
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'sms_gateway';
```

---

## 📞 Support

For database issues:
1. Check Supabase Dashboard logs
2. Verify RLS policies
3. Check schema exposure settings
4. Review migration history
