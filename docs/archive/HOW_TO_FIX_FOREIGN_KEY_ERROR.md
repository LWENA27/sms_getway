## How to Get Real User IDs and Run Test Data SQL

### ERROR YOU GOT

```
ERROR: 23503: insert or update on table "clients" violates foreign key constraint
Key (owner_id)=(550e8400-e29b-41d4-a716-446655440000) is not present in table "users"
```

**Cause:** The hardcoded UUID doesn't exist in Supabase Auth. You need real user IDs first.

---

### SOLUTION

### Step 1: Create Auth Users in Supabase (3 users)

1. Go to **Supabase Dashboard**
2. Click **Authentication** tab (left sidebar)
3. Click **Users** sub-tab
4. Click **Add User** button (top right)
5. Create these 3 users one by one:

**User 1:**
- Email: `john_doe@techstartup.com`
- Password: `Test123!@`
- Click "Create user"

**User 2:**
- Email: `jane_smith@techstartup.com`
- Password: `Test123!@`
- Click "Create user"

**User 3:**
- Email: `bob_jones@techstartup.com`
- Password: `Test123!@`
- Click "Create user"

---

### Step 2: Get Real User IDs

After creating users, you'll see them in the Users list. Each has an ID column showing a UUID:

```
User ID Column Looks Like:
f47ac10b-58cc-4372-a567-0e02b2c3d479
```

**Copy these 3 IDs:**
- John's ID: `_________________________________` (copy from Supabase)
- Jane's ID: `_________________________________` (copy from Supabase)
- Bob's ID: `_________________________________` (copy from Supabase)

---

### Step 3: Update sample_test_data.sql

Open the file in VS Code: `database/sample_test_data.sql`

Find and replace **exactly 3 placeholder strings:**

**Find #1 (Line ~20):**
```sql
v_user_id uuid := 'REPLACE-WITH-JOHN-ID'::uuid;
```
Replace with:
```sql
v_user_id uuid := '550e8400-e29b-41d4-a716-446655440000'::uuid;
```
(Paste John's real ID inside the quotes)

**Find #2 (Line ~57):**
```sql
v_user_2_id uuid := 'REPLACE-WITH-JANE-ID'::uuid;
```
Replace with:
```sql
v_user_2_id uuid := '550e8400-e29b-41d4-a716-446655440001'::uuid;
```
(Paste Jane's real ID inside the quotes)

**Find #3 (Line ~58):**
```sql
v_user_3_id uuid := 'REPLACE-WITH-BOB-ID'::uuid;
```
Replace with:
```sql
v_user_3_id uuid := '550e8400-e29b-41d4-a716-446655440002'::uuid;
```
(Paste Bob's real ID inside the quotes)

---

### Step 4: Run Updated SQL in Supabase

1. Go to **Supabase Dashboard** → **SQL Editor**
2. Click **New Query**
3. **Copy entire** sample_test_data.sql (with real IDs)
4. **Paste** into editor
5. Click **Run** button

**Expected Output:**
```
✅ Test Data Setup Complete!
   Client: Tech Startup Company
   Tenant: SMS Workspace 1
   Users: John Doe (Admin), Jane Smith (Admin), Bob Jones (Member)
   Contacts: 3 sample contacts created
   Group: Sales Team with 2 members
```

---

### Quick Copy-Paste Template

If you prefer, use this template and fill in your real IDs:

```sql
-- REPLACE THE 3 UUIDs BELOW WITH REAL USER IDS FROM SUPABASE AUTH

-- Line 20: John's ID
v_user_id uuid := 'PASTE-JOHN-ID-HERE'::uuid;

-- Line 57: Jane's ID
v_user_2_id uuid := 'PASTE-JANE-ID-HERE'::uuid;

-- Line 58: Bob's ID
v_user_3_id uuid := 'PASTE-BOB-ID-HERE'::uuid;
```

---

### Troubleshooting

**Problem: Still getting "Key not present in table users" error**
- Solution: Double-check you copied the EXACT UUID from Supabase Auth tab
- Verify it's inside quotes: `'550e8400...'::uuid`
- Make sure you replaced all 3 UUIDs

**Problem: Can't find Auth Users in Supabase**
- Solution: Click "Authentication" in left sidebar → "Users" tab

**Problem: Created users but don't see them**
- Solution: Refresh the page (F5)
- Users appear instantly after "Create user" button

**Problem: Can't find User ID**
- Solution: The ID is in the leftmost column of the Users table
- It's a long UUID starting with random characters

---

### Next Steps After Successful Run

After test data runs successfully:

1. ✅ All tables created (clients, tenants, profiles, contacts, groups)
2. ✅ Test client "Tech Startup Company" created
3. ✅ Test tenant "SMS Workspace 1" created
4. ✅ 3 test users added with access
5. ✅ Sample contacts created
6. ✅ Sample group created

**Then proceed with:** Flutter app implementation (Step 3 is already done, just uncomment code)

---

### Verification Query (Optional)

After running test data, verify it worked by running this query in SQL Editor:

```sql
-- Check clients
SELECT * FROM public.clients WHERE slug = 'tech-startup-co';

-- Check tenants
SELECT * FROM sms_gateway.tenants WHERE slug = 'sms-workspace-1';

-- Check users
SELECT gu.email, c.name as client, cpa.role 
FROM public.global_users gu
JOIN public.clients c ON gu.client_id = c.id
JOIN public.client_product_access cpa ON gu.id = cpa.user_id
WHERE c.slug = 'tech-startup-co';

-- Check contacts
SELECT * FROM sms_gateway.contacts WHERE name LIKE '%Contact%';

-- Check groups
SELECT * FROM sms_gateway.groups WHERE name = 'Sales Team';
```

All should return data! ✅
