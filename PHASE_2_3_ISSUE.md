# Phase 2.3 API Integration - Current Issue

**Date:** December 23, 2025  
**Status:** 🔴 Blocked - Function Overloading Conflict  
**Phase:** 2.3 - API-Triggered SMS (REST API for external systems)

## Problem Summary

The SMS API endpoint (`/sms-api/send`) is returning a 500 error due to a **PostgREST function overloading conflict**. There are two versions of `public.submit_sms_request` with conflicting signatures, causing PostgREST to be unable to choose which function to call.

---

## Error Details

### Error Code
```
PGRST203: Could not choose the best candidate function
```

### Full Error Message
```
Could not choose the best candidate function between:
  - public.submit_sms_request(p_api_key => text, p_phone_number => text, p_message => text, p_external_id => text, p_priority => integer, p_scheduled_at => timestamp with time zone, p_metadata => jsonb)
  - public.submit_sms_request(p_api_key => text, p_phone_number => text, p_message => text, p_external_id => text, p_priority => text, p_scheduled_at => timestamp with time zone, p_metadata => jsonb)
```

**Key Difference:** `p_priority` parameter type differs (`integer` vs `text`)

---

## What Works

✅ **Database migrations applied successfully**
- `sms_requests` table created with all columns including `updated_at`
- `api_rate_limits` table created with `updated_at` column
- Database functions in `sms_gateway` schema exist

✅ **Edge Function deployed**
- URL: `https://kzjgdeqfmxkmpmadtbpb.supabase.co/functions/v1/sms-api`
- JWT verification: Disabled
- GET `/sms-api` (docs endpoint): ✅ Working

✅ **API Key created and working**
- Key: `sgw_bbf7bfaab1a94da6bd8b78cb5b6729cb`
- Validation: ✅ Working

✅ **Flutter integration complete**
- `ApiSmsQueueService` created
- `ApiSettingsScreen` created with 3 tabs (API Keys, Queue, Documentation)
- UI integrated into settings

---

## What's Broken

❌ **POST `/sms-api/send` endpoint**
- Returns: 500 Internal Server Error
- Cause: Function overloading conflict in PostgREST

❌ **Root Cause**
There are **two versions** of `public.submit_sms_request` function with conflicting signatures.

---

## Solution Required

### Step 1: Identify Duplicate Functions (i alredy run this succesfull)
Run this query to list all versions:
```sql
SELECT 
    p.proname AS function_name,
    pg_get_function_arguments(p.oid) AS arguments,
    pg_get_function_identity_arguments(p.oid) AS identity_args
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' AND p.proname = 'submit_sms_request';
```

### Step 2: Drop Incorrect Version (i run and it return "Error: Failed to run sql query: ERROR: 42601: syntax error at or near "the" LINE 1: Drop the incorrect version (priority as text) ^")
Drop the version with `p_priority text`:
```sql
-- Drop the incorrect version (priority as text)
DROP FUNCTION IF EXISTS public.submit_sms_request(text, text, text, text, text, timestamptz, jsonb);
```

### Step 3: Verify Correct Version Exists
The correct signature should be:
```sql
public.submit_sms_request(
    p_api_key text,
    p_phone_number text,
    p_message text,
    p_external_id text DEFAULT NULL,
    p_priority integer DEFAULT 0,
    p_scheduled_at timestamptz DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
) RETURNS jsonb
```

### Step 4: Recreate Wrapper if Needed
If the correct version doesn't exist, create it:
```sql
CREATE OR REPLACE FUNCTION public.submit_sms_request(
    p_api_key text,
    p_phone_number text,
    p_message text,
    p_external_id text DEFAULT NULL,
    p_priority integer DEFAULT 0,
    p_scheduled_at timestamptz DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN sms_gateway.submit_sms_request(
        p_api_key, 
        p_phone_number, 
        p_message,
        p_external_id, 
        p_priority, 
        p_scheduled_at, 
        p_metadata
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_sms_request(text, text, text, text, integer, timestamptz, jsonb)
TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
```

### Step 5: Test
```powershell
$headers = @{"x-api-key" = "sgw_bbf7bfaab1a94da6bd8b78cb5b6729cb"; "Content-Type" = "application/json"}
$body = '{"phone_number": "+1234567890", "message": "Hello from API test!"}'
Invoke-RestMethod -Uri "https://kzjgdeqfmxkmpmadtbpb.supabase.co/functions/v1/sms-api/send" -Method POST -Headers $headers -Body $body
```

Expected response:
```json
{
  "success": true,
  "request_id": "<uuid>",
  "status": "pending",
  "message": "SMS request queued successfully"
}
```

---

## Files Created/Modified

### New Files
- `supabase/migrations/20251223_sms_api_requests.sql` - Database schema
- `supabase/migrations/20251223_fix_api_keys_rls.sql` - RLS policies
- `supabase/functions/sms-api/index.ts` - Edge Function
- `lib/services/api_sms_queue_service.dart` - Flutter service
- `lib/screens/api_settings_screen.dart` - Flutter UI
- `API_DOCUMENTATION.md` - API docs

### Modified Files
- `pubspec.yaml` - Added `crypto: ^3.0.3`
- `lib/screens/settings_screen.dart` - Added API Integration link

---

## Database State

### Tables
- ✅ `sms_gateway.sms_requests` (with `updated_at` column)
- ✅ `sms_gateway.api_rate_limits` (with `updated_at` column)
- ✅ `sms_gateway.api_keys`

### Functions
- ✅ `sms_gateway.submit_sms_request` - Core logic (correct signature)
- ❌ `public.submit_sms_request` - **DUPLICATE VERSIONS** (needs cleanup)
- ✅ `sms_gateway.submit_bulk_sms_request`
- ✅ `sms_gateway.get_sms_request_status`
- ✅ `sms_gateway.validate_api_key`

### Triggers
- ❌ No trigger on `sms_requests` (removed to fix earlier issue)
- ✅ Triggers exist on other tables (users, contacts, groups, etc.)

---

## Edge Function Details

**Location:** `supabase/functions/sms-api/index.ts`  
**URL:** `https://kzjgdeqfmxkmpmadtbpb.supabase.co/functions/v1/sms-api`  
**Authentication:** API Key via `x-api-key` header  
**JWT:** Disabled

### Endpoints
- `GET /sms-api` or `GET /sms-api/docs` - API documentation ✅
- `POST /sms-api/send` - Send single SMS ❌ (function conflict)
- `POST /sms-api/bulk` - Send bulk SMS ❌ (function conflict)
- `GET /sms-api/status/:id` - Get SMS status ❌ (function conflict)

---

## Previous Issues Resolved

1. ✅ **Missing `submit_sms_request` function** - Created in `sms_gateway` schema
2. ✅ **Schema mismatch** - Created public wrapper to call `sms_gateway.submit_sms_request`
3. ✅ **RLS policy errors** - Added RLS policies for `api_keys` table
4. ✅ **JWT authentication** - Disabled JWT verification on Edge Function
5. ✅ **Missing `updated_at` column** - Added to `api_rate_limits` and `sms_requests`
6. ✅ **Trigger errors** - Removed trigger from `sms_requests` table

---

## Test Data

**API Key:** `sgw_bbf7bfaab1a94da6bd8b78cb5b6729cb`  
**Test Payload:**
```json
{
  "phone_number": "+1234567890",
  "message": "Hello from API test!"
}
```

---

## Next Steps

1. Run queries in **Step 1** above to identify duplicate functions
2. Drop the incorrect version (Step 2)
3. Verify/recreate correct version (Steps 3-4)
4. Test endpoint (Step 5)
5. If successful, mark Phase 2.3 as ✅ Complete

---

## Contact

If you need more context:
- Check Edge Function logs: Supabase Dashboard → Functions → sms-api → Logs
- Database schema: See attached `schema-sms_getway` file
- Migration files: `supabase/migrations/20251223_*.sql`

---

**Status:** Ready for fix - All context provided above
