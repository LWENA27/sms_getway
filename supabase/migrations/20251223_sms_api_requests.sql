-- ============================================================================
-- Phase 2.3: API-Triggered SMS - SMS Requests Queue Table
-- ============================================================================
-- This migration creates the sms_requests table for external API integration.
-- External systems can submit SMS requests via REST API, and the mobile app
-- will poll this table and process pending requests.
-- ============================================================================

-- Create the sms_requests table for API queue
CREATE TABLE IF NOT EXISTS "sms_gateway"."sms_requests" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "tenant_id" uuid NOT NULL,
    "api_key_id" uuid NOT NULL,                    -- Reference to api_keys table
    "phone_number" character varying(20) NOT NULL,  -- Recipient phone number
    "message" text NOT NULL,                        -- SMS message content
    "status" character varying(20) DEFAULT 'pending' NOT NULL,  -- pending, processing, sent, failed, cancelled
    "priority" integer DEFAULT 0,                   -- Higher = more priority
    "scheduled_at" timestamp with time zone,        -- Optional: schedule for future
    "processed_at" timestamp with time zone,        -- When the SMS was processed
    "error_message" text,                           -- Error details if failed
    "external_id" character varying(255),           -- Optional: caller's reference ID
    "metadata" jsonb DEFAULT '{}'::jsonb,           -- Additional data from API caller
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "sms_requests_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "sms_requests_api_key_id_fkey" FOREIGN KEY ("api_key_id") 
        REFERENCES "sms_gateway"."api_keys"("id") ON DELETE CASCADE,
    CONSTRAINT "sms_requests_status_check" 
        CHECK (status IN ('pending', 'processing', 'sent', 'failed', 'cancelled'))
);

ALTER TABLE "sms_gateway"."sms_requests" OWNER TO "postgres";

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS "idx_sms_requests_tenant_status" 
    ON "sms_gateway"."sms_requests" ("tenant_id", "status");

CREATE INDEX IF NOT EXISTS "idx_sms_requests_api_key" 
    ON "sms_gateway"."sms_requests" ("api_key_id");

CREATE INDEX IF NOT EXISTS "idx_sms_requests_pending" 
    ON "sms_gateway"."sms_requests" ("status", "priority" DESC, "created_at" ASC)
    WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS "idx_sms_requests_scheduled" 
    ON "sms_gateway"."sms_requests" ("scheduled_at")
    WHERE status = 'pending' AND scheduled_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS "idx_sms_requests_external_id" 
    ON "sms_gateway"."sms_requests" ("external_id")
    WHERE external_id IS NOT NULL;

-- Trigger to update updated_at timestamp
CREATE TRIGGER "set_updated_at_sms_requests"
    BEFORE UPDATE ON "sms_gateway"."sms_requests"
    FOR EACH ROW
    EXECUTE FUNCTION "sms_gateway"."update_updated_at_column"();

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS
ALTER TABLE "sms_gateway"."sms_requests" ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their tenant's SMS requests
CREATE POLICY "Users can view own tenant sms_requests"
    ON "sms_gateway"."sms_requests"
    FOR SELECT
    USING (
        tenant_id IN (
            SELECT tenant_id FROM "sms_gateway"."users" 
            WHERE id = auth.uid()
        )
    );

-- Policy: Users can insert SMS requests (via API with valid key)
CREATE POLICY "Users can insert sms_requests"
    ON "sms_gateway"."sms_requests"
    FOR INSERT
    WITH CHECK (
        tenant_id IN (
            SELECT tenant_id FROM "sms_gateway"."users" 
            WHERE id = auth.uid()
        )
    );

-- Policy: Users can update their tenant's SMS requests
CREATE POLICY "Users can update own tenant sms_requests"
    ON "sms_gateway"."sms_requests"
    FOR UPDATE
    USING (
        tenant_id IN (
            SELECT tenant_id FROM "sms_gateway"."users" 
            WHERE id = auth.uid()
        )
    );

-- Policy: Users can delete their tenant's SMS requests
CREATE POLICY "Users can delete own tenant sms_requests"
    ON "sms_gateway"."sms_requests"
    FOR DELETE
    USING (
        tenant_id IN (
            SELECT tenant_id FROM "sms_gateway"."users" 
            WHERE id = auth.uid()
        )
    );

-- ============================================================================
-- API Rate Limiting Table (optional, for tracking API usage)
-- ============================================================================

CREATE TABLE IF NOT EXISTS "sms_gateway"."api_rate_limits" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "api_key_id" uuid NOT NULL,
    "window_start" timestamp with time zone NOT NULL,
    "request_count" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "api_rate_limits_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "api_rate_limits_api_key_id_fkey" FOREIGN KEY ("api_key_id") 
        REFERENCES "sms_gateway"."api_keys"("id") ON DELETE CASCADE,
    CONSTRAINT "api_rate_limits_unique" UNIQUE ("api_key_id", "window_start")
);

ALTER TABLE "sms_gateway"."api_rate_limits" OWNER TO "postgres";

-- ============================================================================
-- Helper function to validate API key and get tenant
-- ============================================================================

CREATE OR REPLACE FUNCTION "sms_gateway"."validate_api_key"(p_api_key text)
RETURNS TABLE (
    api_key_id uuid,
    user_id uuid,
    tenant_id uuid,
    is_valid boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_key_hash text;
BEGIN
    -- Hash the provided key (using SHA-256)
    v_key_hash := encode(digest(p_api_key, 'sha256'), 'hex');
    
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

-- ============================================================================
-- Function to submit SMS request via API
-- ============================================================================

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
    
    -- Insert SMS request
    INSERT INTO "sms_gateway"."sms_requests" (
        tenant_id,
        api_key_id,
        phone_number,
        message,
        external_id,
        priority,
        scheduled_at,
        metadata
    )
    VALUES (
        v_tenant_id,
        v_api_key_id,
        trim(p_phone_number),
        trim(p_message),
        p_external_id,
        p_priority,
        p_scheduled_at,
        p_metadata
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

-- ============================================================================
-- Function to submit bulk SMS requests via API
-- ============================================================================

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
    
    -- Insert SMS requests for each phone number
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
            metadata
        )
        VALUES (
            v_tenant_id,
            v_api_key_id,
            trim(v_phone),
            trim(p_message),
            p_external_id,
            p_priority,
            p_scheduled_at,
            p_metadata
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

-- ============================================================================
-- Function to get SMS request status
-- ============================================================================

CREATE OR REPLACE FUNCTION "sms_gateway"."get_sms_request_status"(
    p_api_key text,
    p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_api_key_id uuid;
    v_user_id uuid;
    v_tenant_id uuid;
    v_is_valid boolean;
    v_request record;
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
    
    -- Get request status
    SELECT * INTO v_request
    FROM "sms_gateway"."sms_requests"
    WHERE id = p_request_id AND tenant_id = v_tenant_id;
    
    IF v_request IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Request not found'
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'request_id', v_request.id,
        'phone_number', v_request.phone_number,
        'status', v_request.status,
        'external_id', v_request.external_id,
        'created_at', v_request.created_at,
        'processed_at', v_request.processed_at,
        'error_message', v_request.error_message
    );
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION "sms_gateway"."validate_api_key"(text) TO authenticated;
GRANT EXECUTE ON FUNCTION "sms_gateway"."submit_sms_request"(text, text, text, text, integer, timestamp with time zone, jsonb) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION "sms_gateway"."submit_bulk_sms_request"(text, text[], text, text, integer, timestamp with time zone, jsonb) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION "sms_gateway"."get_sms_request_status"(text, uuid) TO authenticated, anon;

-- Grant table permissions for service role
GRANT ALL ON "sms_gateway"."sms_requests" TO authenticated;
GRANT ALL ON "sms_gateway"."api_rate_limits" TO authenticated;
