## QUICK TEST DATA REFERENCE

### Pre-made Test Scenarios

Use these SQL snippets to quickly create test data for different scenarios.

---

## Scenario 1: Single Tenant User (Auto-Select)

**Perfect for:** Testing seamless login experience

```sql
-- Prerequisites: Have 1 user in Supabase Auth
-- User ID: USER_ID_1
-- Email: user1@example.com

DO $$
DECLARE
  v_user_id uuid := 'USER_ID_1'::uuid; -- REPLACE
  v_client_id uuid;
  v_tenant_id uuid;
BEGIN
  -- Create client
  SELECT public.create_client(
    p_owner_id := v_user_id,
    p_client_name := 'Solo Business',
    p_client_slug := 'solo-business',
    p_client_email := 'admin@solobusiness.com',
    p_owner_name := 'Solo Owner',
    p_owner_email := 'user1@example.com'
  ) INTO v_client_id;
  
  -- Subscribe to SMS Gateway
  SELECT public.subscribe_client_to_product(
    p_client_id := v_client_id,
    p_product_schema := 'sms_gateway',
    p_tenant_name := 'Main Workspace',
    p_tenant_slug := 'main-workspace',
    p_plan_type := 'pro'
  ) INTO v_tenant_id;
  
  -- Create profile
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_user_id, 'user1@example.com', 'Solo Owner', v_tenant_id, 'admin')
  ON CONFLICT (id) DO NOTHING;
  
  RAISE NOTICE 'Created single-tenant user: %', v_user_id;
END $$;
```

**Test:** Login → Should auto-select "Main Workspace" → Go to home

---

## Scenario 2: Multi-Tenant User (Show Picker)

**Perfect for:** Testing tenant selection UI

```sql
-- Prerequisites: Have 1 user in Supabase Auth
-- User ID: USER_ID_2
-- Email: user2@example.com

DO $$
DECLARE
  v_user_id uuid := 'USER_ID_2'::uuid; -- REPLACE
  v_client_id uuid;
  v_product_id uuid;
BEGIN
  -- Create client
  SELECT public.create_client(
    p_owner_id := v_user_id,
    p_client_name := 'Multi-Workspace Company',
    p_client_slug := 'multi-workspace-co',
    p_client_email := 'admin@multiworkspace.com',
    p_owner_name := 'Multi Owner',
    p_owner_email := 'user2@example.com'
  ) INTO v_client_id;
  
  -- Get SMS Gateway product
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = 'sms_gateway' LIMIT 1;
  
  -- Create TENANT 1
  DECLARE
    v_tenant_1_id uuid := gen_random_uuid();
  BEGIN
    INSERT INTO public.product_subscriptions (product_id, client_id, tenant_id, status, plan_type)
    VALUES (v_product_id, v_client_id, v_tenant_1_id, 'active', 'pro');
    
    INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
    VALUES (v_user_id, v_client_id, v_product_id, v_tenant_1_id, 'owner');
    
    INSERT INTO sms_gateway.tenants (id, name, slug, client_id)
    VALUES (v_tenant_1_id, 'Sales Team Workspace', 'sales-workspace', v_client_id);
    
    INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
    VALUES (v_user_id, 'user2@example.com', 'Multi Owner', v_tenant_1_id, 'admin')
    ON CONFLICT (id) DO UPDATE SET tenant_id = v_tenant_1_id;
  END;
  
  -- Create TENANT 2
  DECLARE
    v_tenant_2_id uuid := gen_random_uuid();
  BEGIN
    INSERT INTO public.product_subscriptions (product_id, client_id, tenant_id, status, plan_type)
    VALUES (v_product_id, v_client_id, v_tenant_2_id, 'active', 'pro');
    
    INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
    VALUES (v_user_id, v_client_id, v_product_id, v_tenant_2_id, 'owner');
    
    INSERT INTO sms_gateway.tenants (id, name, slug, client_id)
    VALUES (v_tenant_2_id, 'Customer Support Workspace', 'support-workspace', v_client_id);
    
    INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
    VALUES (v_user_id, 'user2@example.com', 'Multi Owner', v_tenant_2_id, 'admin')
    ON CONFLICT (id) DO UPDATE SET tenant_id = v_tenant_2_id;
  END;
  
  RAISE NOTICE 'Created multi-tenant user with 2 workspaces: %', v_user_id;
END $$;
```

**Test:** Login → Should show TenantSelectorScreen → Pick "Sales Team Workspace" → Load that tenant's data

---

## Scenario 3: Admin + Team Members (Role Testing)

**Perfect for:** Testing different user roles

```sql
-- Prerequisites: Have 3 users in Supabase Auth
-- Admin: ADMIN_ID (email: admin@company.com)
-- Member 1: MEMBER_1_ID (email: member1@company.com)
-- Member 2: MEMBER_2_ID (email: member2@company.com)

DO $$
DECLARE
  v_admin_id uuid := 'ADMIN_ID'::uuid; -- REPLACE
  v_member_1_id uuid := 'MEMBER_1_ID'::uuid; -- REPLACE
  v_member_2_id uuid := 'MEMBER_2_ID'::uuid; -- REPLACE
  v_client_id uuid;
  v_tenant_id uuid;
  v_product_id uuid;
BEGIN
  -- Create client (admin owns it)
  SELECT public.create_client(
    p_owner_id := v_admin_id,
    p_client_name := 'Team Company',
    p_client_slug := 'team-company',
    p_client_email := 'admin@company.com',
    p_owner_name := 'Team Admin',
    p_owner_email := 'admin@company.com'
  ) INTO v_client_id;
  
  -- Subscribe to SMS Gateway
  SELECT public.subscribe_client_to_product(
    p_client_id := v_client_id,
    p_product_schema := 'sms_gateway',
    p_tenant_name := 'Company SMS Hub',
    p_tenant_slug := 'company-sms-hub',
    p_plan_type := 'enterprise'
  ) INTO v_tenant_id;
  
  -- Admin profile
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_admin_id, 'admin@company.com', 'Team Admin', v_tenant_id, 'admin')
  ON CONFLICT (id) DO NOTHING;
  
  -- Get product ID
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = 'sms_gateway' LIMIT 1;
  
  -- Add Member 1
  PERFORM public.add_user_to_client_product(
    p_user_id := v_member_1_id,
    p_client_id := v_client_id,
    p_product_schema := 'sms_gateway',
    p_tenant_id := v_tenant_id,
    p_role := 'admin',
    p_user_email := 'member1@company.com',
    p_user_name := 'Member One'
  );
  
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_member_1_id, 'member1@company.com', 'Member One', v_tenant_id, 'admin')
  ON CONFLICT (id) DO UPDATE SET tenant_id = v_tenant_id;
  
  -- Add Member 2
  PERFORM public.add_user_to_client_product(
    p_user_id := v_member_2_id,
    p_client_id := v_client_id,
    p_product_schema := 'sms_gateway',
    p_tenant_id := v_tenant_id,
    p_role := 'member',
    p_user_email := 'member2@company.com',
    p_user_name := 'Member Two'
  );
  
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_member_2_id, 'member2@company.com', 'Member Two', v_tenant_id, 'member')
  ON CONFLICT (id) DO NOTHING;
  
  RAISE NOTICE 'Created team with 1 admin + 2 members in single tenant';
END $$;
```

**Test:** 
- Login as admin → Auto-select → Full access ✅
- Login as member 1 → Auto-select → Admin access ✅
- Login as member 2 → Auto-select → Read-only access ✅

---

## Scenario 4: Test Data Isolation

**Perfect for:** Verifying cross-contamination doesn't happen

```sql
-- Add 2 users to DIFFERENT tenants within same client

DO $$
DECLARE
  v_user_1_id uuid := 'USER_ID_1'::uuid; -- REPLACE
  v_user_2_id uuid := 'USER_ID_2'::uuid; -- REPLACE
  v_client_id uuid;
  v_product_id uuid;
  v_tenant_1_id uuid;
  v_tenant_2_id uuid;
BEGIN
  -- Create client
  SELECT public.create_client(
    p_owner_id := v_user_1_id,
    p_client_name := 'Isolation Test',
    p_client_slug := 'isolation-test',
    p_client_email := 'test@isolation.com',
    p_owner_name := 'Test Owner',
    p_owner_email := 'user1@example.com'
  ) INTO v_client_id;
  
  -- Get product
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = 'sms_gateway' LIMIT 1;
  
  -- Create Tenant A
  v_tenant_1_id := gen_random_uuid();
  INSERT INTO public.product_subscriptions (product_id, client_id, tenant_id, status, plan_type)
  VALUES (v_product_id, v_client_id, v_tenant_1_id, 'active', 'pro');
  
  INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
  VALUES (v_user_1_id, v_client_id, v_product_id, v_tenant_1_id, 'owner');
  
  INSERT INTO sms_gateway.tenants (id, name, slug, client_id)
  VALUES (v_tenant_1_id, 'Tenant A', 'tenant-a', v_client_id);
  
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_user_1_id, 'user1@example.com', 'User One', v_tenant_1_id, 'admin')
  ON CONFLICT (id) DO NOTHING;
  
  -- Create Tenant B
  v_tenant_2_id := gen_random_uuid();
  INSERT INTO public.product_subscriptions (product_id, client_id, tenant_id, status, plan_type)
  VALUES (v_product_id, v_client_id, v_tenant_2_id, 'active', 'pro');
  
  INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
  VALUES (v_user_2_id, v_client_id, v_product_id, v_tenant_2_id, 'owner');
  
  INSERT INTO sms_gateway.tenants (id, name, slug, client_id)
  VALUES (v_tenant_2_id, 'Tenant B', 'tenant-b', v_client_id);
  
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_user_2_id, 'user2@example.com', 'User Two', v_tenant_2_id, 'admin')
  ON CONFLICT (id) DO NOTHING;
  
  RAISE NOTICE 'Created 2 separate tenants for isolation testing';
END $$;
```

**Test Data to Add:**
```sql
-- User 1 adds contact to Tenant A
INSERT INTO sms_gateway.contacts (tenant_id, user_id, name, phone_number)
VALUES ('TENANT_A_ID', 'USER_1_ID', 'Alice (Tenant A)', '+256701234567');

-- User 2 adds contact to Tenant B
INSERT INTO sms_gateway.contacts (tenant_id, user_id, name, phone_number)
VALUES ('TENANT_B_ID', 'USER_2_ID', 'Bob (Tenant B)', '+256702345678');
```

**Test:**
- Login User 1, select Tenant A → See "Alice" contact ✅
- Login User 2, select Tenant B → NOT see "Alice" ✅
- Login User 1 again → Still see "Alice" in Tenant A ✅

---

## Scenario 5: Permission Test (No Cross-Product Access)

**Perfect for:** Verifying users from other products are rejected

```sql
-- This should FAIL - user not in SMS Gateway schema

-- Assuming Jane is in inventorymaster.profiles but NOT sms_gateway.profiles
SELECT * FROM sms_gateway.profiles WHERE id = 'JANE_ID'; -- Returns NULL

-- When Jane tries to login:
-- 1. Supabase Auth succeeds ✅
-- 2. Check sms_gateway.profiles → NULL ❌
-- 3. Error: "User not registered for SMS Gateway"
-- 4. Database sharing completely hidden ✅
```

---

## Verification Queries

Run these to check your test data:

```sql
-- List all clients
SELECT id, name, slug FROM public.clients;

-- List all tenants
SELECT id, name, slug, client_id FROM sms_gateway.tenants;

-- List all users with SMS Gateway access
SELECT 
  gu.email,
  c.name as client,
  cpa.role,
  t.name as tenant
FROM public.global_users gu
JOIN public.clients c ON gu.client_id = c.id
JOIN public.client_product_access cpa ON gu.id = cpa.user_id
JOIN sms_gateway.tenants t ON cpa.tenant_id = t.id
WHERE cpa.product_id = (SELECT id FROM public.products WHERE schema_name = 'sms_gateway');

-- Count tenants per user
SELECT 
  gu.email,
  COUNT(DISTINCT cpa.tenant_id) as tenant_count
FROM public.global_users gu
JOIN public.client_product_access cpa ON gu.id = cpa.user_id
WHERE cpa.product_id = (SELECT id FROM public.products WHERE schema_name = 'sms_gateway')
GROUP BY gu.email;

-- List all SMS Gateway contacts
SELECT id, tenant_id, name, phone_number FROM sms_gateway.contacts ORDER BY created_at DESC LIMIT 10;

-- Check profiles
SELECT id, email, name, tenant_id, role FROM sms_gateway.profiles ORDER BY created_at DESC;
```

---

## Cleanup (If Testing Gets Messy)

```sql
-- Delete all test data but keep schema
DELETE FROM sms_gateway.group_members;
DELETE FROM sms_gateway.groups;
DELETE FROM sms_gateway.contacts;
DELETE FROM sms_gateway.sms_logs;
DELETE FROM sms_gateway.profiles;
DELETE FROM sms_gateway.api_keys;
DELETE FROM sms_gateway.settings;
DELETE FROM sms_gateway.audit_logs;
DELETE FROM sms_gateway.tenants;
DELETE FROM public.client_product_access;
DELETE FROM public.product_subscriptions;
DELETE FROM public.global_users WHERE id NOT IN (SELECT id FROM auth.users);
DELETE FROM public.clients;

-- Verify clean state
SELECT COUNT(*) as contacts FROM sms_gateway.contacts; -- Should be 0
SELECT COUNT(*) as tenants FROM sms_gateway.tenants; -- Should be 0
SELECT COUNT(*) as clients FROM public.clients; -- Should be 0
```

---

**Pro Tip:** Keep these scenarios handy for regression testing before each deploy! 🧪
