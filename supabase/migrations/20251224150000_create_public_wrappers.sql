-- Create wrapper functions in public schema to enable PostgREST exposure
-- These functions forward calls to the authoritative sms_gateway functions

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
    RETURN "sms_gateway"."get_sms_request_status"(
        p_api_key,
        p_request_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION "public"."submit_sms_request"(text, text, text, text, integer, timestamp with time zone, jsonb) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION "public"."submit_bulk_sms_request"(text, text[], text, text, integer, timestamp with time zone, jsonb) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION "public"."get_sms_request_status"(text, uuid) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';
