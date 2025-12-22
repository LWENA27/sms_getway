# SMS Gateway - Schema Isolation Migration Guide

## Overview

The SMS Gateway application now uses a dedicated database schema (`sms_gateway`) for complete data isolation from other products using the same Supabase instance.

## Changes Made

### 1. Database Schema Changes
- **New Schema**: `sms_gateway`
- **All tables** now reside in the `sms_gateway` schema instead of the public schema
- **Complete isolation** from other applications' data

### 2. Table Structure
All tables have been moved to the `sms_gateway` schema:
- `sms_gateway.users`
- `sms_gateway.contacts`
- `sms_gateway.groups`
- `sms_gateway.group_members`
- `sms_gateway.sms_logs`
- `sms_gateway.api_keys`
- `sms_gateway.audit_logs`
- `sms_gateway.settings`

### 3. Flutter Code Updates
All database queries in the Flutter app have been updated to reference the new schema:
- Changed from `from('table_name')` to `from('sms_gateway.table_name')`
- Updated in all screen files:
  - `lib/screens/contacts_screen.dart`
  - `lib/screens/groups_screen.dart`
  - `lib/screens/bulk_sms_screen.dart`
  - `lib/screens/sms_logs_screen.dart`
  - `lib/main.dart`

## Migration Steps

### Step 1: Backup Existing Data (Optional)
```sql
-- Backup existing tables to archive schema
CREATE SCHEMA archive;
ALTER TABLE public.users SET SCHEMA archive;
ALTER TABLE public.contacts SET SCHEMA archive;
ALTER TABLE public.groups SET SCHEMA archive;
ALTER TABLE public.group_members SET SCHEMA archive;
ALTER TABLE public.sms_logs SET SCHEMA archive;
ALTER TABLE public.api_keys SET SCHEMA archive;
ALTER TABLE public.audit_logs SET SCHEMA archive;
ALTER TABLE public.settings SET SCHEMA archive;
```

### Step 2: Execute New Schema
Execute the SQL script in Supabase SQL Editor:
```
File: database/schema_isolated.sql
Location: SQL Editor > New Query > Paste content
```

This will:
- Create the `sms_gateway` schema
- Create all tables in the new schema
- Apply Row Level Security (RLS) policies
- Create indexes for performance
- Set up automatic timestamp triggers

### Step 3: Migrate Existing Data (If Applicable)
If you have existing data in the public schema:

```sql
-- Copy users data
INSERT INTO sms_gateway.users
SELECT * FROM public.users;

-- Copy contacts
INSERT INTO sms_gateway.contacts
SELECT * FROM public.contacts;

-- Copy groups
INSERT INTO sms_gateway.groups
SELECT * FROM public.groups;

-- Copy group members
INSERT INTO sms_gateway.group_members
SELECT * FROM public.group_members;

-- Copy SMS logs
INSERT INTO sms_gateway.sms_logs
SELECT * FROM public.sms_logs;

-- Copy API keys
INSERT INTO sms_gateway.api_keys
SELECT * FROM public.api_keys;

-- Copy audit logs
INSERT INTO sms_gateway.audit_logs
SELECT * FROM public.audit_logs;

-- Copy settings
INSERT INTO sms_gateway.settings
SELECT * FROM public.settings;
```

### Step 4: Rebuild Flutter App
```bash
cd sms_getway
flutter clean
flutter pub get
flutter run
```

## Verification

### Database Level
```sql
-- Verify schema exists
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name = 'sms_gateway';

-- List all tables in schema
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'sms_gateway';

-- Verify RLS is enabled
SELECT schemaname, tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'sms_gateway';
```

### App Level
1. ✅ Login and verify authentication works
2. ✅ Create a new contact
3. ✅ Create a group with members
4. ✅ Send an SMS message
5. ✅ View SMS logs
6. ✅ Check logs are persisted in database

## Benefits

### 1. Data Isolation
- Complete separation from other applications
- No accidental data leaks or conflicts
- Clear ownership and management

### 2. Performance
- Dedicated schema for faster queries
- Cleaner index organization
- Better resource allocation

### 3. Security
- Row Level Security (RLS) policies specific to SMS Gateway
- User data completely isolated by schema
- Audit trail for compliance

### 4. Scalability
- Easy to add features without affecting other apps
- Can create backups/archives of entire schema
- Simple migration path for multi-tenancy

### 5. Maintenance
- All SMS Gateway objects in one place
- Easier backup and restore operations
- Clear schema structure for developers

## Rollback (If Needed)

If you need to revert to the public schema:

```sql
-- Move tables back to public schema
ALTER TABLE sms_gateway.users SET SCHEMA public;
ALTER TABLE sms_gateway.contacts SET SCHEMA public;
ALTER TABLE sms_gateway.groups SET SCHEMA public;
ALTER TABLE sms_gateway.group_members SET SCHEMA public;
ALTER TABLE sms_gateway.sms_logs SET SCHEMA public;
ALTER TABLE sms_gateway.api_keys SET SCHEMA public;
ALTER TABLE sms_gateway.audit_logs SET SCHEMA public;
ALTER TABLE sms_gateway.settings SET SCHEMA public;

-- Drop empty schema
DROP SCHEMA sms_gateway;
```

Then update Flutter code back to original `from('table_name')` references.

## Files Changed

### New Files
- `database/schema_isolated.sql` - New isolated schema definition

### Modified Files
- `lib/screens/contacts_screen.dart` - Updated all database queries
- `lib/screens/groups_screen.dart` - Updated all database queries
- `lib/screens/bulk_sms_screen.dart` - Updated all database queries
- `lib/screens/sms_logs_screen.dart` - Updated all database queries
- `lib/main.dart` - Updated home page data loading

## Troubleshooting

### Error: "relation "sms_gateway.contacts" does not exist"
**Solution**: Execute `schema_isolated.sql` in Supabase SQL Editor first

### Error: "permission denied for schema sms_gateway"
**Solution**: Grant necessary permissions:
```sql
GRANT USAGE ON SCHEMA sms_gateway TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA sms_gateway TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA sms_gateway TO authenticated;
```

### App Not Syncing Data
**Solution**: 
1. Verify RLS policies are enabled
2. Check that current user exists in `sms_gateway.users`
3. Review app logs for specific error messages

## Support

For questions or issues with the schema migration:
1. Check the SQL execution logs in Supabase console
2. Review app runtime errors in Flutter logs
3. Verify network connectivity to Supabase
4. Confirm authentication token is valid

---

*Updated: December 22, 2025*
*Status: Schema isolation complete and tested*
