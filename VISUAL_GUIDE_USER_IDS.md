## VISUAL GUIDE: Getting Real User IDs from Supabase

### The Problem
```
You tried to run sample_test_data.sql with placeholder UUIDs
550e8400-e29b-41d4-a716-446655440000  ← This doesn't exist!
660e8400-e29b-41d4-a716-446655440001  ← This doesn't exist!
770e8400-e29b-41d4-a716-446655440002  ← This doesn't exist!
```

**ERROR:** Foreign key constraint failed - users don't exist

---

### The Solution in 4 Steps

#### STEP 1: Create 3 Test Users in Supabase

**Location:** Supabase Dashboard → Authentication → Users Tab

```
┌─────────────────────────────────────────────────────┐
│  AUTHENTICATION > USERS                             │
│                              [Add User] button       │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Click "Add User" to create:                        │
│  • john_doe@techstartup.com                         │
│  • jane_smith@techstartup.com                       │
│  • bob_jones@techstartup.com                        │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Form for each user:**
```
┌─────────────────────────────────┐
│ Add User                        │
├─────────────────────────────────┤
│ Email: john_doe@techstartup.com │
│ Password: Test123!@             │
│                                 │
│         [Create user]           │
└─────────────────────────────────┘
```

Repeat 3 times (John, Jane, Bob)

---

#### STEP 2: Copy User IDs from the Table

**After creating users, you see this table:**

```
┌──────────────────────────────────────────────────────────┐
│  USERS TABLE                                             │
├──────────────────────────────────────────────────────────┤
│ ID (Copy This!) │ Email                    │ Created    │
├──────────────────────────────────────────────────────────┤
│ f47ac10b-58cc.. │ john_doe@techstartup.com │ 2 min ago  │
│ 8b5f2c3d-91e.. │ jane_smith@techstartup.. │ 1 min ago  │
│ 6c4e1a9f-7bd.. │ bob_jones@techstartup..  │ 1 min ago  │
├──────────────────────────────────────────────────────────┤
```

**Copy these 3 IDs:**
- John: `f47ac10b-58cc-4372-a567-0e02b2c3d479`
- Jane: `8b5f2c3d-91e6-4f8a-b2c9-1d5e7a4f6c8b`
- Bob: `6c4e1a9f-7bd4-4e3a-a6f9-2c8d1a5f9b7e`

(Copy EXACT UUIDs from YOUR Supabase dashboard)

---

#### STEP 3: Edit sample_test_data.sql

**File location:** `database/sample_test_data.sql`

**Find these 3 lines and replace:**

**Line ~20 - Find:**
```sql
v_user_id uuid := 'REPLACE-WITH-JOHN-ID'::uuid;
```
**Replace with:**
```sql
v_user_id uuid := 'f47ac10b-58cc-4372-a567-0e02b2c3d479'::uuid;
```

**Line ~57 - Find:**
```sql
v_user_2_id uuid := 'REPLACE-WITH-JANE-ID'::uuid;
```
**Replace with:**
```sql
v_user_2_id uuid := '8b5f2c3d-91e6-4f8a-b2c9-1d5e7a4f6c8b'::uuid;
```

**Line ~58 - Find:**
```sql
v_user_3_id uuid := 'REPLACE-WITH-BOB-ID'::uuid;
```
**Replace with:**
```sql
v_user_3_id uuid := '6c4e1a9f-7bd4-4e3a-a6f9-2c8d1a5f9b7e'::uuid;
```

---

#### STEP 4: Run in Supabase SQL Editor

```
Supabase Dashboard → SQL Editor → New Query
│
├─ Copy entire sample_test_data.sql
│
├─ Paste into editor
│
├─ Click [Run] button
│
└─ ✅ SUCCESS!
```

**Expected result:**
```
✅ Test Data Setup Complete!
   Client: Tech Startup Company
   Tenant: SMS Workspace 1
   Users: John Doe (Admin), Jane Smith (Admin), Bob Jones (Member)
   Contacts: 3 sample contacts created
   Group: Sales Team with 2 members
```

---

### Timeline

| Step | Time | Action |
|------|------|--------|
| 1 | 3 min | Create 3 users in Supabase Auth |
| 2 | 2 min | Copy 3 real user IDs |
| 3 | 3 min | Edit sample_test_data.sql (3 replacements) |
| 4 | 2 min | Run in SQL Editor |
| **TOTAL** | **~10 min** | **Done!** |

---

### Common Mistakes to Avoid

❌ **WRONG:** Using placeholder UUIDs
```sql
'550e8400-e29b-41d4-a716-446655440000'::uuid  ← DOESN'T EXIST
```

✅ **CORRECT:** Using real Supabase user IDs
```sql
'f47ac10b-58cc-4372-a567-0e02b2c3d479'::uuid  ← REAL ID FROM SUPABASE
```

---

❌ **WRONG:** Forgetting to replace all 3 UUIDs
```sql
Line 20: 'REPLACE-WITH-JOHN-ID'  ← STILL PLACEHOLDER!
Line 57: '8b5f2c3d-91e6-4f8a-b2c9-1d5e7a4f6c8b'  ✓
Line 58: '6c4e1a9f-7bd4-4e3a-a6f9-2c8d1a5f9b7e'  ✓
```

✅ **CORRECT:** All 3 replaced with real IDs
```sql
Line 20: 'f47ac10b-58cc-4372-a567-0e02b2c3d479'  ✓
Line 57: '8b5f2c3d-91e6-4f8a-b2c9-1d5e7a4f6c8b'  ✓
Line 58: '6c4e1a9f-7bd4-4e3a-a6f9-2c8d1a5f9b7e'  ✓
```

---

❌ **WRONG:** Typo or partial UUID
```sql
'f47ac10b-58cc-4372-a567-0e02b2c3d47'  ← INCOMPLETE!
```

✅ **CORRECT:** Full UUID, exactly as shown in Supabase
```sql
'f47ac10b-58cc-4372-a567-0e02b2c3d479'  ← EXACT COPY
```

---

### Verification

Run this query AFTER test data succeeds:

```sql
-- Should show 3 users
SELECT email FROM sms_gateway.profiles ORDER BY created_at;

-- Should show 1 client
SELECT name FROM public.clients WHERE slug = 'tech-startup-co';

-- Should show 1 tenant
SELECT name FROM sms_gateway.tenants WHERE slug = 'sms-workspace-1';

-- Should show 3 contacts
SELECT name FROM sms_gateway.contacts ORDER BY created_at LIMIT 3;

-- Should show 1 group
SELECT name FROM sms_gateway.groups WHERE name = 'Sales Team';
```

All queries should return data ✅

---

### You're Ready!

Once test data runs successfully:
1. ✅ migration.sql executed
2. ✅ sample_test_data.sql executed with real user IDs
3. ✅ All database tables populated
4. **Next:** Uncomment Flutter code (Step 3)

**Total implementation time: ~60 minutes** 🚀
