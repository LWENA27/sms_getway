-- ============================================================================
-- Create Public Schema Wrapper Functions
-- Date: December 24, 2025
-- Purpose: PostgREST exposes public schema functions. Create thin wrappers
--          that forward calls to the authoritative sms_gateway functions
-- ============================================================================

-- Wrapper for submit_sms_request - routes to sms_gateway
CREATE OR REPLACE FUNCTION "public"."submit_sms_request"(
    p_api_key text,
    p_phone_number text,
    p_message text,
    p_external_id text DEFAULT NULL,
    p_priority integer DEFAULT 0,
    p_scheduled_at timestamp with time zone DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, sms_gateway
AS $$
BEGIN
    -- Forward to the authoritative function in sms_gateway schema
    RETURN "sms_gateway"."submit_sms_request"(
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

-- Wrapper for submit_bulk_sms_request - routes to sms_gateway
CREATE OR REPLACE FUNCTION "public"."submit_bulk_sms_request"(
    p_api_key text,
    p_phone_numbers text[],
    p_message text,
    p_external_id text DEFAULT NULL,
    p_priority integer DEFAULT 0,
    p_scheduled_at timestamp with time zone DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, sms_gateway
AS $$
BEGIN
    -- Forward to the authoritative function in sms_gateway schema
    RETURN "sms_gateway"."submit_bulk_sms_request"(
        p_api_key,
        p_phone_numbers,
        p_message,
        p_external_id,
        p_priority,
        p_scheduled_at,
        p_metadata
    );
END;
$$;

-- Wrapper for get_sms_request_status - routes to sms_gateway
CREATE OR REPLACE FUNCTION "public"."get_sms_request_status"(
    p_api_key text,
    p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, sms_gateway
AS $$
BEGIN
    -- Forward to the authoritative function in sms_gateway schema
    RETURN "sms_gateway"."get_sms_request_status"(
        p_api_key,
        p_request_id
    );
END;
$$;

-- Grant permissions for PostgREST exposure
GRANT EXECUTE ON FUNCTION "public"."submit_sms_request"(text, text, text, text, integer, timestamp with time zone, jsonb) 
TO authenticated, anon;

GRANT EXECUTE ON FUNCTION "public"."submit_bulk_sms_request"(text, text[], text, text, integer, timestamp with time zone, jsonb) 
TO authenticated, anon;

GRANT EXECUTE ON FUNCTION "public"."get_sms_request_status"(text, uuid) 
TO authenticated, anon;

-- Notify PostgREST to reload schema
NOTIFY pgrst, 'reload schema';

-- ============================================================================
-- Notes:
-- ============================================================================
-- ARCHITECTURE:
-- - sms_gateway schema: Contains all business logic (authoritative)
-- - public schema: Contains thin wrapper functions for PostgREST exposure
-- - Edge Functions: Call public.* functions via RPC
-- - PostgREST: Exposes public.* functions as /rpc/ endpoints
--
-- This approach:
-- 1. Maintains clean separation (all logic in sms_gateway)
-- 2. Prevents function conflicts (only one version in public)
-- 3. Allows PostgREST to find and expose functions
-- 4. Provides single point of entry for all SMS operations
-- ============================================================================
