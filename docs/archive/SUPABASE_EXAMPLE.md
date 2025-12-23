# Example: Adding a New Feature to SMS Gateway

This example shows you how to add an email field to contacts.

## Step 1: Create a New Migration

```bash
cd /home/lwena/sms_getway
supabase migration new add_email_to_contacts
```

## Step 2: Edit the Migration File

The command above will create a file like:
`supabase/migrations/20251223XXXXXX_add_email_to_contacts.sql`

Add your SQL changes:

```sql
-- Add email column to contacts table
ALTER TABLE sms_gateway.contacts 
ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Add index for email searches
CREATE INDEX IF NOT EXISTS idx_contacts_email 
ON sms_gateway.contacts(email);

-- Add a comment
COMMENT ON COLUMN sms_gateway.contacts.email IS 'Contact email address';
```

## Step 3: Test Locally (Optional but Recommended)

```bash
# Start local Supabase
supabase start

# This will output:
# - API URL: http://127.0.0.1:54321
# - GraphQL URL: http://127.0.0.1:54321/graphql/v1
# - Studio URL: http://127.0.0.1:54323
# - Inbucket URL: http://127.0.0.1:54324
# - DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
# - anon key: your_anon_key
# - service_role key: your_service_role_key

# Apply all migrations to local database
supabase db reset

# Open Studio to verify changes
# Visit: http://127.0.0.1:54323
```

## Step 4: Push to Remote

Once you're satisfied with the changes:

```bash
# Push migrations to remote database
supabase db push

# Output will show:
# - Which migrations are being applied
# - Success or error messages
```

## Step 5: Verify

```bash
# Check that migrations are synced
supabase migration list

# You should see your new migration in both Local and Remote columns
```

## Step 6: Update Your Flutter App

Now you can use the new field in your app:

```dart
// In lib/contacts/contact_model.dart
class Contact {
  final String id;
  final String name;
  final String phone;
  final String? email; // New field
  // ... other fields

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'], // New field
      // ... other fields
    );
  }
}

// When querying:
final contacts = await supabase
    .from('sms_gateway.contacts')
    .select('id, name, phone, email') // Include new field
    .eq('tenant_id', tenantId);
```

## Step 7: Stop Local Services (if running)

```bash
supabase stop
```

---

## Quick Commands Summary

```bash
# Pull latest from remote
supabase db pull

# Create new migration
supabase migration new <description>

# Start local dev
supabase start

# Apply migrations locally
supabase db reset

# Push to remote
supabase db push

# Check status
supabase migration list

# Stop local dev
supabase stop
```
