-- Fix validate_api_key function to use pgcrypto extension properly

CREATE OR REPLACE FUNCTION "sms_gateway"."validate_api_key"(p_api_key text)
RETURNS TABLE (
    api_key_id uuid,
    user_id uuid,
    tenant_id uuid,
    is_valid boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = sms_gateway, extensions, public
AS $$
DECLARE
    v_key_hash text;
BEGIN
    -- Hash the provided key (using SHA-256)
    v_key_hash := encode(extensions.digest(p_api_key, 'sha256'), 'hex');
    
    RETURN QUERY
    SELECT 
        ak.id as api_key_id,
        ak.user_id,
        ak.tenant_id,
        (ak.active = true) as is_valid
    FROM "sms_gateway"."api_keys" ak
    WHERE ak.key_hash = v_key_hash
    LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION "sms_gateway"."validate_api_key"(text) TO authenticated;
