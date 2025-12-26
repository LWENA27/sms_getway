-- Drop the existing trigger that's causing issues
DROP TRIGGER IF EXISTS "set_updated_at_sms_requests" ON "sms_gateway"."sms_requests";

-- Recreate the trigger function to handle both INSERT and UPDATE
CREATE OR REPLACE FUNCTION "sms_gateway"."update_updated_at_column"() RETURNS TRIGGER AS $$
BEGIN
    -- Only update the column if it exists and we're in an UPDATE operation
    -- For INSERT, the column should already be set in the function
    IF TG_OP = 'UPDATE' THEN
        NEW.updated_at = CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END
$$ LANGUAGE plpgsql;

-- Recreate the trigger for UPDATE operations only
CREATE TRIGGER "set_updated_at_sms_requests"
    BEFORE UPDATE ON "sms_gateway"."sms_requests"
    FOR EACH ROW
    EXECUTE FUNCTION "sms_gateway"."update_updated_at_column"();

-- Fix submit_sms_request to include updated_at in INSERT
CREATE OR REPLACE FUNCTION "sms_gateway"."submit_sms_request"(
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
SET search_path = sms_gateway, extensions, public
AS $$
DECLARE
    v_api_key_id uuid;
    v_user_id uuid;
    v_tenant_id uuid;
    v_is_valid boolean;
    v_request_id uuid;
    v_rate_count integer;
BEGIN
    -- Validate API key
    SELECT * INTO v_api_key_id, v_user_id, v_tenant_id, v_is_valid
    FROM "sms_gateway"."validate_api_key"(p_api_key);
    
    IF v_api_key_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid API key'
        );
    END IF;
    
    IF NOT v_is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'API key is inactive'
        );
    END IF;
    
    -- Check rate limit (100 requests per minute per key)
    SELECT COALESCE(SUM(request_count), 0) INTO v_rate_count
    FROM "sms_gateway"."api_rate_limits"
    WHERE api_key_id = v_api_key_id
      AND window_start > NOW() - INTERVAL '1 minute';
    
    IF v_rate_count >= 100 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Rate limit exceeded. Max 100 requests per minute.'
        );
    END IF;
    
    -- Update rate limit counter
    INSERT INTO "sms_gateway"."api_rate_limits" (api_key_id, window_start, request_count)
    VALUES (v_api_key_id, date_trunc('minute', NOW()), 1)
    ON CONFLICT (api_key_id, window_start) 
    DO UPDATE SET request_count = "sms_gateway"."api_rate_limits".request_count + 1;
    
    -- Validate phone number (basic check)
    IF p_phone_number IS NULL OR length(trim(p_phone_number)) < 10 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid phone number'
        );
    END IF;
    
    -- Validate message
    IF p_message IS NULL OR length(trim(p_message)) = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Message cannot be empty'
        );
    END IF;
    
    -- Insert SMS request with explicit updated_at
    INSERT INTO "sms_gateway"."sms_requests" (
        tenant_id,
        api_key_id,
        phone_number,
        message,
        external_id,
        priority,
        scheduled_at,
        metadata,
        created_at,
        updated_at
    )
    VALUES (
        v_tenant_id,
        v_api_key_id,
        trim(p_phone_number),
        trim(p_message),
        p_external_id,
        p_priority,
        p_scheduled_at,
        COALESCE(p_metadata, '{}'::jsonb),
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
    )
    RETURNING id INTO v_request_id;
    
    -- Update last_used timestamp on API key
    UPDATE "sms_gateway"."api_keys"
    SET last_used = NOW()
    WHERE id = v_api_key_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_request_id,
        'status', 'pending',
        'message', 'SMS request queued successfully'
    );
END;
$$;

-- Same for bulk
CREATE OR REPLACE FUNCTION "sms_gateway"."submit_bulk_sms_request"(
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
SET search_path = sms_gateway, extensions, public
AS $$
DECLARE
    v_api_key_id uuid;
    v_user_id uuid;
    v_tenant_id uuid;
    v_is_valid boolean;
    v_request_ids uuid[];
    v_phone text;
    v_request_id uuid;
    v_count integer := 0;
BEGIN
    -- Validate API key
    SELECT * INTO v_api_key_id, v_user_id, v_tenant_id, v_is_valid
    FROM "sms_gateway"."validate_api_key"(p_api_key);
    
    IF v_api_key_id IS NULL OR NOT v_is_valid THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Invalid or inactive API key'
        );
    END IF;
    
    -- Validate message
    IF p_message IS NULL OR length(trim(p_message)) = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Message cannot be empty'
        );
    END IF;
    
    -- Check recipients count (max 1000 per request)
    IF array_length(p_phone_numbers, 1) > 1000 THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Maximum 1000 recipients per bulk request'
        );
    END IF;
    
    -- Insert SMS requests for each phone number with explicit timestamps
    FOREACH v_phone IN ARRAY p_phone_numbers
    LOOP
        INSERT INTO "sms_gateway"."sms_requests" (
            tenant_id,
            api_key_id,
            phone_number,
            message,
            external_id,
            priority,
            scheduled_at,
            metadata,
            created_at,
            updated_at
        )
        VALUES (
            v_tenant_id,
            v_api_key_id,
            trim(v_phone),
            trim(p_message),
            p_external_id,
            p_priority,
            p_scheduled_at,
            COALESCE(p_metadata, '{}'::jsonb),
            CURRENT_TIMESTAMP,
            CURRENT_TIMESTAMP
        )
        RETURNING id INTO v_request_id;
        
        v_request_ids := array_append(v_request_ids, v_request_id);
        v_count := v_count + 1;
    END LOOP;
    
    -- Update last_used timestamp on API key
    UPDATE "sms_gateway"."api_keys"
    SET last_used = NOW()
    WHERE id = v_api_key_id;
    
    RETURN jsonb_build_object(
        'success', true,
        'request_ids', v_request_ids,
        'count', v_count,
        'status', 'pending',
        'message', format('%s SMS requests queued successfully', v_count)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION "sms_gateway"."submit_sms_request"(text, text, text, text, integer, timestamp with time zone, jsonb) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION "sms_gateway"."submit_bulk_sms_request"(text, text[], text, text, integer, timestamp with time zone, jsonb) TO authenticated, anon;
