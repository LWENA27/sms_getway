# 🔍 SQL Files Analysis - Conflict Detection & Resolution

## 📁 Database Files Overview

### Files Present:
1. **schema.sql** - Original basic schema (old, single-tenant)
2. **schema_isolated.sql** - Clean sms_gateway schema (no multi-tenant)
3. **public_schema_control_plane.sql** - Control plane tables
4. **add_multi_tenant_support.sql** - Adds tenant_id to all tables
5. **migration.sql** - Large migration script (different approach)
6. **sample_test_data.sql** - Test data with helper functions

---

## ⚠️ **CONFLICTS DETECTED**

### **CRITICAL CONFLICT #1: Two Different Architectures**

#### Architecture A (Recommended - Simpler):
```
Files: schema_isolated.sql → public_schema_control_plane.sql → add_multi_tenant_support.sql
```
- Creates `sms_gateway` schema with basic tables
- Creates `public` control plane separately
- Adds `tenant_id` columns via ALTER TABLE
- Uses `product` field (TEXT) in `client_product_access`

#### Architecture B (Complex):
```
File: migration.sql
```
- Complete migration from scratch
- Creates `products` table with `schema_name` field
- Uses `product_id` (UUID) in relationships
- Different table structure for control plane

**❌ These two approaches are INCOMPATIBLE**

---

### **CONFLICT #2: `client_product_access` Table**

#### In `public_schema_control_plane.sql`:
```sql
CREATE TABLE public.client_product_access (
  ...
  product VARCHAR(100) NOT NULL,  -- ← TEXT field
  ...
);
```

#### In `migration.sql`:
```sql
CREATE TABLE public.client_product_access (
  ...
  product_id UUID NOT NULL,  -- ← UUID field, references products table
  ...
);
```

**❌ Cannot have both versions**

---

### **CONFLICT #3: RLS Policies in `add_multi_tenant_support.sql`**

The file tries to DROP and CREATE policies that may not exist yet:

```sql
DROP POLICY IF EXISTS "Users can view their own profile" ON sms_gateway.users;
```

But `schema_isolated.sql` **doesn't create these policies**!

**⚠️ This will cause errors if run before policies exist**

---

### **CONFLICT #4: Old `schema.sql`**

This file creates tables in `public` schema (not `sms_gateway`):
```sql
CREATE TABLE IF NOT EXISTS users (...);  -- No schema prefix!
CREATE TABLE IF NOT EXISTS contacts (...);
```

**❌ This is the OLD architecture and conflicts with everything else**

---

### **CONFLICT #5: `sample_test_data.sql` Dependencies**

Requires helper functions that don't exist in any schema file:
```sql
SELECT public.create_client(...);  -- Function doesn't exist
SELECT public.subscribe_client_to_product(...);  -- Function doesn't exist
```

---

## ✅ **RECOMMENDED SOLUTION**

### **Use Architecture A (Clean Approach)**

**Execution Order:**
```
1. public_schema_control_plane.sql    ← Control plane
2. schema_isolated.sql                ← SMS Gateway schema
3. add_multi_tenant_support_FIXED.sql ← Add tenant_id (needs fixing)
4. Add basic RLS policies              ← Missing step
5. sample_test_data_FIXED.sql         ← Fix test data (optional)
```

**Files to IGNORE:**
- ❌ `schema.sql` - Old architecture
- ❌ `migration.sql` - Different approach, too complex

---

## 🔧 **REQUIRED FIXES**

### **Fix #1: Create Missing RLS Policies**

`schema_isolated.sql` creates tables but NO policies. We need to add them BEFORE running `add_multi_tenant_support.sql`.

### **Fix #2: Fix `add_multi_tenant_support.sql`**

Current issue:
```sql
DROP POLICY IF EXISTS "Users can view their own profile" ON sms_gateway.users;
```

This policy doesn't exist yet! The DROP will succeed (IF EXISTS), but we need to CREATE basic policies first.

### **Fix #3: Helper Functions Missing**

`sample_test_data.sql` needs:
- `public.create_client()`
- `public.subscribe_client_to_product()`
- `public.add_user_to_client_product()`

These are in `migration.sql` but we're not using that file.

---

## 📋 **RECOMMENDED EXECUTION PLAN**

### **Step 1: Clean Slate**
```sql
-- Drop everything and start fresh
DROP SCHEMA IF EXISTS sms_gateway CASCADE;
-- Keep public schema, just clean tables
DROP TABLE IF EXISTS public.client_product_access CASCADE;
DROP TABLE IF EXISTS public.product_usage_stats CASCADE;
DROP TABLE IF EXISTS public.product_subscriptions CASCADE;
DROP TABLE IF EXISTS public.global_users CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
```

### **Step 2: Execute in Order**

#### 2.1: Control Plane
```bash
psql < database/public_schema_control_plane.sql
```

#### 2.2: SMS Gateway Schema  
```bash
psql < database/schema_isolated.sql
```

#### 2.3: Basic RLS Policies (NEW FILE NEEDED)
```bash
psql < database/basic_rls_policies.sql  # We need to create this
```

#### 2.4: Multi-Tenant Support
```bash
psql < database/add_multi_tenant_support.sql  # After basic policies exist
```

---

## 🚨 **WHAT FAILS IN `add_multi_tenant_support.sql`**

### Policies Being Dropped That Don't Exist:

1. ❌ `"Users can view their own profile"` - Never created
2. ❌ `"Users can update their own profile"` - Never created
3. ❌ `"Users can view their own contacts"` - Never created
4. ❌ `"Users can insert their own contacts"` - Never created
5. ❌ `"Users can update their own contacts"` - Never created
6. ❌ `"Users can delete their own contacts"` - Never created
7. ❌ `"Users can view their own groups"` - Never created
8. ❌ `"Users can insert their own groups"` - Never created
9. ❌ `"Users can update their own groups"` - Never created
10. ❌ `"Users can delete their own groups"` - Never created
11. ❌ `"Users can view their group members"` - Never created
12. ❌ `"Users can insert group members for their groups"` - Never created
13. ❌ `"Users can delete group members from their groups"` - Never created
14. ❌ `"Users can view their own SMS logs"` - Never created
15. ❌ `"Users can insert their own SMS logs"` - Never created
16. ❌ `"Users can update their own SMS logs"` - Never created
17. ❌ `"Users can view their own API keys"` - Never created
18. ❌ `"Users can insert their own API keys"` - Never created
19. ❌ `"Users can update their own API keys"` - Never created
20. ❌ `"Users can delete their own API keys"` - Never created
21. ❌ `"Users can view their own audit logs"` - Never created
22. ❌ `"Users can view their own settings"` - Never created
23. ❌ `"Users can insert their own settings"` - Never created
24. ❌ `"Users can update their own settings"` - Never created
25. ❌ `"Users can delete their own settings"` - Never created

**These policies are referenced but never defined in `schema_isolated.sql`**

---

## ✅ **SOLUTION: Create Missing Files**

### **File 1: `basic_rls_policies.sql`**

Create all basic policies that `add_multi_tenant_support.sql` tries to drop.

### **File 2: `consolidated_migration.sql`**

Single file that runs everything in order with proper error handling.

---

## 📊 **FILE DEPENDENCY GRAPH**

```
┌─────────────────────────────────────────┐
│  public_schema_control_plane.sql        │
│  Creates: public.clients,               │
│           public.global_users, etc.     │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  schema_isolated.sql                    │
│  Creates: sms_gateway.* tables          │
│           (NO tenant_id yet)            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  basic_rls_policies.sql (MISSING!)      │
│  Creates: Basic RLS policies            │
│           WITHOUT tenant checks         │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  add_multi_tenant_support.sql           │
│  - Adds tenant_id columns               │
│  - Drops basic policies                 │
│  - Creates tenant-aware policies        │
└─────────────────────────────────────────┘
```

---

## 🎯 **NEXT STEPS**

1. ✅ Create `basic_rls_policies.sql` file
2. ✅ Create `consolidated_migration.sql` file
3. ✅ Test on local Supabase
4. ✅ Fix any remaining errors
5. ✅ Push to production

---

## ⚠️ **WARNINGS**

### **DO NOT RUN:**
- ❌ `schema.sql` - Old, conflicts with everything
- ❌ `migration.sql` - Different architecture
- ❌ `add_multi_tenant_support.sql` - Until basic policies exist

### **RUN IN ORDER:**
1. ✅ `public_schema_control_plane.sql`
2. ✅ `schema_isolated.sql`
3. ✅ `basic_rls_policies.sql` (NEW)
4. ✅ `add_multi_tenant_support.sql`

---

**Ready to create the missing files and consolidated migration script!**
