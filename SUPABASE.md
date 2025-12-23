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
