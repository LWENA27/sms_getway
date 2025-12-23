-- ============================================================================
-- SIMPLE TEST DATA - Add Your 3 Supabase Auth Users to SMS Gateway
-- ============================================================================
-- This script adds your existing Supabase Auth users to the SMS Gateway
-- 
-- Your users (from Supabase dashboard):
-- 1. bosko@gmail.com       → 0e4f975f-96ee-4fbc-bb78-8f76e865aa16
-- 2. fasemorana@gmail.com  → 855c1d05-d56f-4893-a5e7-c59f73d56166
-- 3. marandijoshua07@gmail.com → f8da838d-1d4e-47fd-b5e7-70228f7f98d (missing last digit, check dashboard)
-- ============================================================================

-- ============================================================================
-- STEP 1: Create a test client (company/organization)
-- ============================================================================

INSERT INTO public.clients (id, name, slug, email, is_active)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'Test Company',
  'test-company',
  'admin@testcompany.com',
  true
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name;

-- ============================================================================
-- STEP 2: Add users to sms_gateway.users table with tenant_id
-- ============================================================================

-- User 1: bosko@gmail.com (Admin)
INSERT INTO sms_gateway.users (id, email, name, phone_number, role, tenant_id)
VALUES (
  '0e4f975f-96ee-4fbc-bb78-8f76e865aa16',
  'bosko@gmail.com',
  'Bosko',
  '+256700000001',
  'admin',
  '11111111-1111-1111-1111-111111111111'
)
ON CONFLICT (id) DO UPDATE
SET 
  email = EXCLUDED.email,
  name = EXCLUDED.name,
  tenant_id = EXCLUDED.tenant_id,
  role = EXCLUDED.role;

-- User 2: fasemorana@gmail.com (Admin)
INSERT INTO sms_gateway.users (id, email, name, phone_number, role, tenant_id)
VALUES (
  '855c1d05-d56f-4893-a5e7-c59f73d56166',
  'fasemorana@gmail.com',
  'Fasemorana',
  '+256700000002',
  'admin',
  '11111111-1111-1111-1111-111111111111'
)
ON CONFLICT (id) DO UPDATE
SET 
  email = EXCLUDED.email,
  name = EXCLUDED.name,
  tenant_id = EXCLUDED.tenant_id,
  role = EXCLUDED.role;

-- User 3: marandijoshua07@gmail.com (User)
-- NOTE: Check the full UUID in your Supabase dashboard
-- The visible UUID in the screenshot ends with "98d" but might be incomplete
INSERT INTO sms_gateway.users (id, email, name, phone_number, role, tenant_id)
VALUES (
  'f8da838d-1d4e-47fd-b5e7-70228f7f98d1', -- You may need to update this UUID
  'marandijoshua07@gmail.com',
  'Marandi Joshua',
  '+256700000003',
  'user',
  '11111111-1111-1111-1111-111111111111'
)
ON CONFLICT (id) DO UPDATE
SET 
  email = EXCLUDED.email,
  name = EXCLUDED.name,
  tenant_id = EXCLUDED.tenant_id,
  role = EXCLUDED.role;

-- ============================================================================
-- STEP 3: Add sample contacts for testing
-- ============================================================================

-- Add 5 sample contacts for User 1 (Bosko)
INSERT INTO sms_gateway.contacts (user_id, tenant_id, name, phone_number)
VALUES
  ('0e4f975f-96ee-4fbc-bb78-8f76e865aa16', '11111111-1111-1111-1111-111111111111', 'Alice Johnson', '+256701234567'),
  ('0e4f975f-96ee-4fbc-bb78-8f76e865aa16', '11111111-1111-1111-1111-111111111111', 'Bob Smith', '+256702345678'),
  ('0e4f975f-96ee-4fbc-bb78-8f76e865aa16', '11111111-1111-1111-1111-111111111111', 'Carol Williams', '+256703456789'),
  ('0e4f975f-96ee-4fbc-bb78-8f76e865aa16', '11111111-1111-1111-1111-111111111111', 'David Brown', '+256704567890'),
  ('0e4f975f-96ee-4fbc-bb78-8f76e865aa16', '11111111-1111-1111-1111-111111111111', 'Eve Davis', '+256705678901')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- STEP 4: Create a sample group
-- ============================================================================

-- Create a test group
INSERT INTO sms_gateway.groups (id, user_id, tenant_id, name, description)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  '0e4f975f-96ee-4fbc-bb78-8f76e865aa16',
  '11111111-1111-1111-1111-111111111111',
  'VIP Customers',
  'Our most important clients'
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name;

-- Add contacts to the group
INSERT INTO sms_gateway.group_members (group_id, contact_id, tenant_id)
SELECT 
  '22222222-2222-2222-2222-222222222222',
  c.id,
  '11111111-1111-1111-1111-111111111111'
FROM sms_gateway.contacts c
WHERE c.user_id = '0e4f975f-96ee-4fbc-bb78-8f76e865aa16'
AND c.tenant_id = '11111111-1111-1111-1111-111111111111'
LIMIT 3
ON CONFLICT DO NOTHING;

-- ============================================================================
-- VERIFICATION: Check what we created
-- ============================================================================

SELECT '=== CLIENTS ===' as info;
SELECT id, name, slug, email FROM public.clients WHERE id = '11111111-1111-1111-1111-111111111111';

SELECT '=== SMS GATEWAY USERS ===' as info;
SELECT id, email, name, role, tenant_id FROM sms_gateway.users 
WHERE tenant_id = '11111111-1111-1111-1111-111111111111'
ORDER BY email;

SELECT '=== CONTACTS ===' as info;
SELECT id, name, phone_number, user_id FROM sms_gateway.contacts 
WHERE tenant_id = '11111111-1111-1111-1111-111111111111'
ORDER BY name;

SELECT '=== GROUPS ===' as info;
SELECT id, name, description FROM sms_gateway.groups 
WHERE tenant_id = '11111111-1111-1111-1111-111111111111';

SELECT '=== GROUP MEMBERS ===' as info;
SELECT gm.group_id, c.name as contact_name, c.phone_number 
FROM sms_gateway.group_members gm
JOIN sms_gateway.contacts c ON gm.contact_id = c.id
WHERE gm.tenant_id = '11111111-1111-1111-1111-111111111111';

-- ============================================================================
-- SUCCESS MESSAGE
-- ============================================================================
SELECT 
  '✅ Test data added successfully!' as status,
  '3 users created' as users,
  '5 sample contacts added' as contacts,
  '1 group with 3 members' as groups,
  'Login with: bosko@gmail.com, fasemorana@gmail.com, or marandijoshua07@gmail.com' as instructions;
