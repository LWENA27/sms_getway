-- Fix API Keys table permissions
-- Run this in Supabase SQL Editor

-- Enable RLS on api_keys table
ALTER TABLE "sms_gateway"."api_keys" ENABLE ROW LEVEL SECURITY;

-- Policy: Users can insert their own API keys
CREATE POLICY "Users can insert own api_keys"
    ON "sms_gateway"."api_keys"
    FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Policy: Users can view their tenant's API keys
CREATE POLICY "Users can view own tenant api_keys"
    ON "sms_gateway"."api_keys"
    FOR SELECT
    USING (
        tenant_id IN (
            SELECT tenant_id FROM "sms_gateway"."users" 
            WHERE id = auth.uid()
        )
    );

-- Policy: Users can update their own API keys
CREATE POLICY "Users can update own api_keys"
    ON "sms_gateway"."api_keys"
    FOR UPDATE
    USING (user_id = auth.uid());

-- Policy: Users can delete their own API keys
CREATE POLICY "Users can delete own api_keys"
    ON "sms_gateway"."api_keys"
    FOR DELETE
    USING (user_id = auth.uid());

-- Grant permissions
GRANT ALL ON "sms_gateway"."api_keys" TO authenticated;
