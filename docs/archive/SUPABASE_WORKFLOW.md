# Supabase Local Development Workflow

## ✅ Setup Complete

Your local Supabase environment is now connected to your remote instance at:
- **Project URL**: https://kzjgdeqfmxkmpmadtbpb.supabase.co
- **Project Ref**: kzjgdeqfmxkmpmadtbpb
- **Database Version**: PostgreSQL 15

## 📁 Project Structure

```
supabase/
├── config.toml                           # Supabase configuration
└── migrations/
    └── 20251222223134_remote_schema.sql  # Current remote schema
```

## 🔄 Development Workflow

### 1. Pull Remote Schema (Already Done)
```bash
supabase db pull
```
This downloads the current remote database schema into a migration file.

### 2. Make Local Changes

#### Option A: Create a New Migration File
```bash
supabase migration new your_change_description
```
This creates a new SQL file in `supabase/migrations/` where you can write your schema changes.

Example migration file name: `20251223120000_add_new_column.sql`

```sql
-- Add a new column to contacts table
ALTER TABLE sms_gateway.contacts 
ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Create an index
CREATE INDEX IF NOT EXISTS idx_contacts_email 
ON sms_gateway.contacts(email);
```

#### Option B: Edit Existing Schema Files
You can also edit the files in your `database/` folder and then create a migration from them.

### 3. Test Changes Locally (Optional)

Start a local Supabase instance:
```bash
supabase start
```

This starts local services on:
- API: http://127.0.0.1:54321
- Studio: http://127.0.0.1:54323
- DB: postgresql://postgres:postgres@127.0.0.1:54322/postgres

Apply migrations locally:
```bash
supabase db reset
```

Stop local services when done:
```bash
supabase stop
```

### 4. Push Changes to Remote

Push your migrations to the remote database:
```bash
supabase db push
```

This will:
- Apply any new migration files to your remote database
- Update the migration history table
- Make changes live in production

### 5. Verify Changes

Check migration status:
```bash
supabase migration list
```

You should see both Local and Remote columns showing the same migrations.

## 📝 Common Commands

### Database Operations
```bash
# Pull remote schema to local
supabase db pull

# Push local migrations to remote
supabase db push

# Create a new migration file
supabase migration new <name>

# List all migrations
supabase migration list

# Diff between local and remote
supabase db diff
```

### Local Development
```bash
# Start local Supabase
supabase start

# Stop local Supabase
supabase stop

# Reset local database (reapply all migrations)
supabase db reset

# View local database logs
supabase db logs
```

### Migration Management
```bash
# Repair migration status (if out of sync)
supabase migration repair --status applied <migration_id>
supabase migration repair --status reverted <migration_id>
```

## 🎯 Example Workflow: Adding a New Feature

Let's say you want to add an `email` column to the contacts table:

```bash
# 1. Create a new migration
supabase migration new add_email_to_contacts

# 2. Edit the new file in supabase/migrations/
# Add your SQL:
#   ALTER TABLE sms_gateway.contacts ADD COLUMN email VARCHAR(255);

# 3. (Optional) Test locally
supabase start
supabase db reset
# Check in Studio: http://127.0.0.1:54323
supabase stop

# 4. Push to remote
supabase db push

# 5. Verify
supabase migration list
```

## 🔐 Schema Information

Your database has multiple schemas:
- `public` - Control plane (client_product_access table)
- `sms_gateway` - SMS Gateway application data
- `smartmenu` - Smart Menu application data
- `inventorymaster` - Inventory Master application data

All queries in your Flutter app should reference the schema explicitly:
```dart
await supabase.from('sms_gateway.contacts').select();
```

## ⚠️ Important Notes

1. **Always Pull Before Making Changes**: Run `supabase db pull` before starting work to ensure you have the latest schema.

2. **Test Before Pushing**: If possible, test migrations locally with `supabase start` before pushing to production.

3. **Migration Files Are Immutable**: Once pushed, don't edit old migration files. Create new ones instead.

4. **Backup Before Major Changes**: Consider backing up your remote database before pushing major schema changes.

5. **RLS Policies**: Remember to set up Row Level Security policies for new tables in multi-tenant setup.

## 🐛 Troubleshooting

### Migration History Out of Sync
```bash
# If you see "migration history does not match" error:
supabase migration repair --status reverted <migration_id>
# or
supabase migration repair --status applied <migration_id>
```

### Can't Connect to Remote
```bash
# Re-link to remote project
supabase link --project-ref kzjgdeqfmxkmpmadtbpb
```

### Database Version Mismatch
Edit `supabase/config.toml`:
```toml
[db]
major_version = 15  # Match your remote version
```

## 📚 Resources

- [Supabase CLI Docs](https://supabase.com/docs/guides/cli)
- [Database Migrations Guide](https://supabase.com/docs/guides/cli/local-development#database-migrations)
- [Multi-tenant Architecture](https://supabase.com/docs/guides/database/postgres/row-level-security)

## ✨ Quick Reference

| Action | Command |
|--------|---------|
| Pull from remote | `supabase db pull` |
| Push to remote | `supabase db push` |
| Create migration | `supabase migration new <name>` |
| List migrations | `supabase migration list` |
| Start local | `supabase start` |
| Stop local | `supabase stop` |
| Reset local DB | `supabase db reset` |
| View diff | `supabase db diff` |

---

**Your Supabase environment is ready! You can now pull, modify, and push database changes seamlessly.** 🚀
