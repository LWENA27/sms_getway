-- ============================================================================
-- SAMPLE TEST DATA FOR SMS GATEWAY MULTI-TENANT
-- ============================================================================
-- This script shows how to:
-- 1. Create a new client (business/organization)
-- 2. Create a new tenant in SMS Gateway for that client
-- 3. Add users with access to that tenant
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE A NEW CLIENT (Business/Organization)
-- ============================================================================
-- Assuming user already exists in auth.users (Supabase Auth)
-- You would have the user ID from Supabase registration
-- For this example, we'll use a placeholder UUID (replace with real user ID)

-- EXAMPLE USER ID (replace with actual from Supabase Auth):
-- User: bosko@gmail.com → ID: 0a4f975f-96ee-4fbc-bb78-8f76e865aa16

DO $$
DECLARE
  v_client_id uuid;
  v_tenant_id uuid;
  v_product_id uuid;
  v_user_id uuid := '0a4f975f-96ee-4fbc-bb78-8f76e865aa16'::uuid; -- bosko@gmail.com
BEGIN
  
  -- =========================================================================
  -- Create the client (business/organization)
  -- =========================================================================
  SELECT public.create_client(
    p_owner_id := v_user_id,
    p_client_name := 'Tech Startup Company',
    p_client_slug := 'tech-startup-co',
    p_client_email := 'admin@techstartup.com',
    p_owner_name := 'John Doe',
    p_owner_email := 'john_doe@techstartup.com'
  ) INTO v_client_id;
  
  RAISE NOTICE 'Created client: %', v_client_id;
  
  -- =========================================================================
  -- Subscribe the client to SMS Gateway product and create a tenant
  -- =========================================================================
  SELECT public.subscribe_client_to_product(
    p_client_id := v_client_id,
    p_product_schema := 'sms_gateway',
    p_tenant_name := 'SMS Workspace 1',
    p_tenant_slug := 'sms-workspace-1',
    p_plan_type := 'pro'
  ) INTO v_tenant_id;
  
  RAISE NOTICE 'Created tenant: % for client: %', v_tenant_id, v_client_id;
  
  -- =========================================================================
  -- Create SMS Gateway profiles (user registration in product)
  -- =========================================================================
  -- The owner already has access from subscribe_client_to_product
  -- Let's add the owner's profile to sms_gateway schema
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_user_id, 'john_doe@techstartup.com', 'John Doe', v_tenant_id, 'admin')
  ON CONFLICT (id) DO UPDATE
  SET tenant_id = v_tenant_id, role = 'admin';
  
  RAISE NOTICE 'Created SMS Gateway profile for owner';
  
END $$;

-- ============================================================================
-- STEP 2: ADD ADDITIONAL USERS TO THE SAME TENANT
-- ============================================================================
-- Now add more team members to the same tenant

DO $$
DECLARE
  v_client_id uuid;
  v_tenant_id uuid;
  v_user_2_id uuid := '855c1d05-d56f-4893-a5e7-c59f73d56166'::uuid; -- fasemorana@gmail.com
  v_user_3_id uuid := 'f8da838d-1d4e-47fd-b5e7-70228f7f98d'::uuid; -- marandi joshua07@gmail.com
BEGIN
  
  -- Get the client and tenant we created above
  SELECT id INTO v_client_id FROM public.clients WHERE slug = 'tech-startup-co' LIMIT 1;
  SELECT t.id INTO v_tenant_id FROM sms_gateway.tenants t 
  JOIN public.product_subscriptions ps ON t.id = ps.tenant_id
  JOIN public.clients c ON ps.client_id = c.id
  WHERE c.id = v_client_id LIMIT 1;
  
  -- =========================================================================
  -- Add User 2 (Team Lead)
  -- =========================================================================
  PERFORM public.add_user_to_client_product(
    p_user_id := v_user_2_id,
    p_client_id := v_client_id,
    p_product_schema := 'sms_gateway',
    p_tenant_id := v_tenant_id,
    p_role := 'admin',
    p_user_email := 'jane_smith@techstartup.com',
    p_user_name := 'Jane Smith'
  );
  
  -- Create SMS Gateway profile for User 2
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_user_2_id, 'jane_smith@techstartup.com', 'Jane Smith', v_tenant_id, 'admin')
  ON CONFLICT (id) DO UPDATE
  SET tenant_id = v_tenant_id, role = 'admin';
  
  RAISE NOTICE 'Added User 2 (Jane Smith) to tenant: %', v_tenant_id;
  
  -- =========================================================================
  -- Add User 3 (Team Member)
  -- =========================================================================
  PERFORM public.add_user_to_client_product(
    p_user_id := v_user_3_id,
    p_client_id := v_client_id,
    p_product_schema := 'sms_gateway',
    p_tenant_id := v_tenant_id,
    p_role := 'member',
    p_user_email := 'bob_jones@techstartup.com',
    p_user_name := 'Bob Jones'
  );
  
  -- Create SMS Gateway profile for User 3
  INSERT INTO sms_gateway.profiles (id, email, name, tenant_id, role)
  VALUES (v_user_3_id, 'bob_jones@techstartup.com', 'Bob Jones', v_tenant_id, 'member')
  ON CONFLICT (id) DO UPDATE
  SET tenant_id = v_tenant_id, role = 'member';
  
  RAISE NOTICE 'Added User 3 (Bob Jones) to tenant: %', v_tenant_id;
  
END $$;

-- ============================================================================
-- STEP 3: CREATE SAMPLE CONTACTS FOR THE TENANT
-- ============================================================================

DO $$
DECLARE
  v_tenant_id uuid;
  v_user_id uuid := '0a4f975f-96ee-4fbc-bb78-8f76e865aa16'::uuid; -- bosko@gmail.com (Owner)
BEGIN
  
  -- Get the tenant
  SELECT t.id INTO v_tenant_id FROM sms_gateway.tenants t 
  WHERE t.slug = 'sms-workspace-1' LIMIT 1;
  
  -- Add sample contacts
  INSERT INTO sms_gateway.contacts (tenant_id, user_id, name, phone_number, email)
  VALUES
    (v_tenant_id, v_user_id, 'Alice Contact', '+256701234567', 'alice@example.com'),
    (v_tenant_id, v_user_id, 'Bob Contact', '+256702345678', 'bob@example.com'),
    (v_tenant_id, v_user_id, 'Charlie Contact', '+256703456789', 'charlie@example.com')
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE 'Added sample contacts to tenant: %', v_tenant_id;
  
END $$;

-- ============================================================================
-- STEP 4: CREATE A SAMPLE GROUP AND ADD CONTACTS
-- ============================================================================

DO $$
DECLARE
  v_tenant_id uuid;
  v_user_id uuid := '0a4f975f-96ee-4fbc-bb78-8f76e865aa16'::uuid; -- bosko@gmail.com (Owner)
  v_group_id uuid;
  v_contact_ids uuid[];
BEGIN
  
  -- Get the tenant
  SELECT t.id INTO v_tenant_id FROM sms_gateway.tenants t 
  WHERE t.slug = 'sms-workspace-1' LIMIT 1;
  
  -- Create a group
  INSERT INTO sms_gateway.groups (tenant_id, user_id, name)
  VALUES (v_tenant_id, v_user_id, 'Sales Team')
  RETURNING id INTO v_group_id;
  
  RAISE NOTICE 'Created group: % for tenant: %', v_group_id, v_tenant_id;
  
  -- Add contacts to the group
  INSERT INTO sms_gateway.group_members (group_id, contact_id)
  SELECT v_group_id, c.id
  FROM sms_gateway.contacts c
  WHERE c.tenant_id = v_tenant_id
  AND c.user_id = v_user_id
  LIMIT 2
  ON CONFLICT DO NOTHING;
  
  RAISE NOTICE 'Added 2 contacts to group: %', v_group_id;
  
END $$;

-- ============================================================================
-- VERIFICATION: Check what we created
-- ============================================================================

-- List all clients
SELECT '=== CLIENTS ===' as section;
SELECT id, name, slug, owner_id, is_active FROM public.clients 
WHERE slug = 'tech-startup-co' ORDER BY created_at;

-- List all tenants for SMS Gateway
SELECT '=== SMS GATEWAY TENANTS ===' as section;
SELECT t.id, t.name, t.slug, t.client_id FROM sms_gateway.tenants t
WHERE t.slug = 'sms-workspace-1' ORDER BY t.created_at;

-- List all users with SMS Gateway access
SELECT '=== USERS WITH SMS GATEWAY ACCESS ===' as section;
SELECT 
  gu.id,
  gu.email,
  gu.name,
  c.name as client_name,
  cpa.role,
  cpa.tenant_id
FROM public.global_users gu
JOIN public.clients c ON gu.client_id = c.id
JOIN public.client_product_access cpa ON gu.id = cpa.user_id
WHERE c.slug = 'tech-startup-co'
AND cpa.product_id = (SELECT id FROM public.products WHERE schema_name = 'sms_gateway')
ORDER BY gu.created_at;

-- List all SMS Gateway profiles
SELECT '=== SMS GATEWAY PROFILES ===' as section;
SELECT sp.id, sp.email, sp.name, sp.tenant_id, sp.role FROM sms_gateway.profiles sp
ORDER BY sp.created_at;

-- List all contacts
SELECT '=== CONTACTS ===' as section;
SELECT c.id, c.tenant_id, c.name, c.phone_number, c.email FROM sms_gateway.contacts c
ORDER BY c.created_at;

-- List all groups
SELECT '=== GROUPS ===' as section;
SELECT g.id, g.tenant_id, g.name FROM sms_gateway.groups g
ORDER BY g.created_at;

-- List group members
SELECT '=== GROUP MEMBERS ===' as section;
SELECT gm.group_id, gm.contact_id, c.name as contact_name FROM sms_gateway.group_members gm
JOIN sms_gateway.contacts c ON gm.contact_id = c.id
ORDER BY gm.created_at;

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT '✅ Test Data Setup Complete!' as status,
       'Client: Tech Startup Company' as info1,
       'Tenant: SMS Workspace 1' as info2,
       'Users: John Doe (Admin), Jane Smith (Admin), Bob Jones (Member)' as info3,
       'Contacts: 3 sample contacts created' as info4,
       'Group: Sales Team with 2 members' as info5;
