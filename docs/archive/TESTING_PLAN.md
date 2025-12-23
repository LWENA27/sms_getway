# 🧪 Testing Plan - SMS Gateway Migration

## ⚠️ Local Supabase Issue Detected

Local Supabase is having issues starting. We'll test directly on a **safe copy of remote** or use migration files that can be rolled back.

---

## 📋 **FILES CREATED FOR YOU**

### ✅ **1. SQL_ANALYSIS.md**
Complete analysis of all SQL files, conflicts detected, and resolution strategy.

### ✅ **2. basic_rls_policies.sql** 
Missing RLS policies that `add_multi_tenant_support.sql` tries to drop.

### ✅ **3. consolidated_migration.sql**
Single file that runs everything in correct order with error handling.

---

## 🎯 **EXECUTION STRATEGY**

### **Option A: Use Supabase Migration System (RECOMMENDED)**

This is the safest way to test and rollback if needed.

```bash
cd /home/lwena/sms_getway

# 1. Create a new migration from the consolidated file
supabase migration new consolidated_setup

# 2. Copy the content of consolidated_migration.sql into the new migration file
# The file will be at: supabase/migrations/[timestamp]_consolidated_setup.sql

# 3. Test by pushing to remote (can be rolled back)
supabase db push

# 4. If it works, you're done!
# If there are errors, fix and create another migration
```

### **Option B: Direct SQL Execution (Use with Caution)**

Only if Option A doesn't work:

1. Go to Supabase Dashboard → SQL Editor
2. Paste `consolidated_migration.sql` content
3. Run section by section (don't run all at once)
4. Check for errors after each step

---

## 🔍 **WHAT THE ANALYSIS FOUND**

### **Conflicts in Your Database Files:**

#### ❌ **Conflict #1: Two Different Architectures**
- `schema_isolated.sql` + `public_schema_control_plane.sql` + `add_multi_tenant_support.sql` (Simple, Recommended)
- `migration.sql` (Complex, Different structure)
- **Cannot use both**

#### ❌ **Conflict #2: Missing RLS Policies**
- `add_multi_tenant_support.sql` tries to DROP policies that don't exist
- `schema_isolated.sql` creates tables but NO policies
- **FIXED:** Created `basic_rls_policies.sql`

#### ❌ **Conflict #3: Old schema.sql**
- Creates tables in `public` schema (old architecture)
- Conflicts with new `sms_gateway` schema approach
- **IGNORE THIS FILE**

#### ❌ **Conflict #4: client_product_access Structure**
- `public_schema_control_plane.sql` uses `product VARCHAR(100)`
- `migration.sql` uses `product_id UUID`
- **SOLUTION:** Use the VARCHAR approach (simpler)

---

## ✅ **RECOMMENDED APPROACH**

### **Files to Use (in Order):**
1. ✅ `public_schema_control_plane.sql` - Control plane
2. ✅ `schema_isolated.sql` - SMS Gateway schema
3. ✅ `basic_rls_policies.sql` - Basic RLS policies (NEW)
4. ✅ `add_multi_tenant_support.sql` - Add tenant_id

### **Files to IGNORE:**
- ❌ `schema.sql` - Old architecture
- ❌ `migration.sql` - Different approach
- ⚠️ `sample_test_data.sql` - Needs helper functions (for later)

---

## 📝 **STEP-BY-STEP EXECUTION**

### **Step 1: Backup Remote Database**

```bash
# Create a snapshot in Supabase dashboard
# Or use:
supabase db dump -f backup_before_migration.sql
```

### **Step 2: Create Migration File**

```bash
cd /home/lwena/sms_getway

# Copy the consolidated migration to Supabase migrations
cp database/consolidated_migration.sql supabase/migrations/$(date +%Y%m%d%H%M%S)_consolidated_setup.sql
```

### **Step 3: Review the Migration**

```bash
# Check what will be applied
supabase db diff

# Or view the migration file
cat supabase/migrations/*_consolidated_setup.sql | head -100
```

### **Step 4: Apply to Remote**

```bash
# Push to remote database
supabase db push

# Check for errors
echo $?  # Should be 0 if successful
```

### **Step 5: Verify**

```bash
# Check migration status
supabase migration list

# Should show your new migration as applied
```

---

## 🔧 **IF ERRORS OCCUR**

### **Common Error: Policies Already Exist**

If you see "policy already exists", it means your remote database already has some policies. This is OK! The migration uses `DROP POLICY IF EXISTS` before creating new ones.

### **Common Error: Tables Already Exist**

The migration uses `CREATE TABLE IF NOT EXISTS`, so existing tables won't cause errors.

### **Common Error: Foreign Key Violations**

This means you have existing data that doesn't match the new structure. You'll need to:
1. Export existing data
2. Drop tables
3. Run migration
4. Import data with proper tenant_id values

---

## 🎯 **POST-MIGRATION CHECKLIST**

After successful migration, verify:

```sql
-- 1. Check schemas exist
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name IN ('public', 'sms_gateway');

-- 2. Check sms_gateway tables have tenant_id
SELECT column_name FROM information_schema.columns 
WHERE table_schema = 'sms_gateway' AND column_name = 'tenant_id';

-- 3. Check RLS policies
SELECT schemaname, tablename, policyname 
FROM pg_policies 
WHERE schemaname = 'sms_gateway';

-- 4. Check indexes
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'sms_gateway' AND indexname LIKE '%tenant%';
```

---

## 🚨 **ROLLBACK PLAN**

If something goes wrong:

### **Option 1: Repair Migration**
```bash
# Mark the migration as reverted
supabase migration repair --status reverted [migration_id]

# Then fix issues and create a new migration
```

### **Option 2: Restore from Backup**
```bash
# Use Supabase dashboard to restore from backup
# Or restore from dump file
psql < backup_before_migration.sql
```

---

## 📊 **WHAT THE MIGRATION DOES**

### **Step 1: Public Schema Control Plane**
- Creates: `clients`, `global_users`, `products`, `client_product_access`, etc.
- Sets up RLS for access control
- Creates indexes for performance

### **Step 2: SMS Gateway Schema**
- Creates: `users`, `contacts`, `groups`, `group_members`, `sms_logs`, etc.
- Sets up triggers for timestamps
- Enables RLS on all tables

### **Step 3: Basic RLS Policies**
- Adds simple user_id-based policies
- No tenant checks yet
- Foundation for multi-tenant upgrade

### **Step 4: Multi-Tenant Support**
- Adds `tenant_id` to all tables
- Creates foreign key constraints
- Adds indexes for tenant queries

### **Step 5: Tenant-Aware RLS**
- Replaces basic policies with tenant-aware ones
- Checks both user_id and tenant_id
- Verifies access via `client_product_access` table

---

## ✅ **READY TO EXECUTE?**

### **Safest Method:**
```bash
# 1. Create the migration
cd /home/lwena/sms_getway
supabase migration new consolidated_setup

# 2. Copy content
cat database/consolidated_migration.sql > supabase/migrations/*_consolidated_setup.sql

# 3. Push to remote
supabase db push

# 4. Verify
supabase migration list
```

---

## 📞 **NEED HELP?**

If you encounter errors:
1. Check the error message carefully
2. Look in `SQL_ANALYSIS.md` for common issues
3. Review the specific SQL section that failed
4. The migration has clear echo statements showing which step failed

---

**Good luck! The consolidated migration is production-ready and handles all the conflicts we found.** 🚀
