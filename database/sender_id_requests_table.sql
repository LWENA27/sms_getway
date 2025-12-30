-- ============================================================================
-- Sender ID Requests Table
-- ============================================================================
-- This table stores customer requests for custom Sender IDs
-- Admin can review and approve/reject requests
-- ============================================================================

CREATE TABLE IF NOT EXISTS "sms_gateway"."sender_id_requests" (
    "id" uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    "tenant_id" uuid NOT NULL REFERENCES "sms_gateway"."tenants"("id") ON DELETE CASCADE,
    "user_id" uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    "sender_id" varchar(11) NOT NULL,
    "business_name" varchar(255) NOT NULL,
    "purpose" text NOT NULL,
    "contact_phone" varchar(20) NOT NULL,
    "status" varchar(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'active')),
    "admin_notes" text,
    "reviewed_by" uuid REFERENCES auth.users(id),
    "reviewed_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Add comments
COMMENT ON TABLE "sms_gateway"."sender_id_requests" IS 
    'Customer requests for custom Sender IDs (the name that appears as SMS sender)';

COMMENT ON COLUMN "sms_gateway"."sender_id_requests"."sender_id" IS 
    'Requested Sender ID (max 11 alphanumeric characters)';

COMMENT ON COLUMN "sms_gateway"."sender_id_requests"."status" IS 
    'Request status: pending (awaiting review), approved (approved but not active), rejected (denied), active (approved and in use)';

COMMENT ON COLUMN "sms_gateway"."sender_id_requests"."admin_notes" IS 
    'Admin comments about the request (reason for rejection, etc.)';

-- Create indexes
CREATE INDEX IF NOT EXISTS "idx_sender_id_requests_tenant" 
    ON "sms_gateway"."sender_id_requests" ("tenant_id");

CREATE INDEX IF NOT EXISTS "idx_sender_id_requests_user" 
    ON "sms_gateway"."sender_id_requests" ("user_id");

CREATE INDEX IF NOT EXISTS "idx_sender_id_requests_status" 
    ON "sms_gateway"."sender_id_requests" ("status");

CREATE INDEX IF NOT EXISTS "idx_sender_id_requests_created" 
    ON "sms_gateway"."sender_id_requests" ("created_at" DESC);

-- Enable RLS
ALTER TABLE "sms_gateway"."sender_id_requests" ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own tenant's requests
CREATE POLICY "Users can view own tenant sender_id_requests"
    ON "sms_gateway"."sender_id_requests"
    FOR SELECT
    USING (
        tenant_id IN (
            SELECT tm.tenant_id 
            FROM "sms_gateway"."tenant_members" tm
            WHERE tm.user_id = auth.uid()
        )
    );

-- Users can insert requests for their tenant
CREATE POLICY "Users can insert sender_id_requests"
    ON "sms_gateway"."sender_id_requests"
    FOR INSERT
    WITH CHECK (
        tenant_id IN (
            SELECT tm.tenant_id 
            FROM "sms_gateway"."tenant_members" tm
            WHERE tm.user_id = auth.uid()
        )
        AND user_id = auth.uid()
    );

-- Only admins can update requests (approve/reject)
-- For now, allow users to update their own pending requests
CREATE POLICY "Users can update own pending requests"
    ON "sms_gateway"."sender_id_requests"
    FOR UPDATE
    USING (
        tenant_id IN (
            SELECT tm.tenant_id 
            FROM "sms_gateway"."tenant_members" tm
            WHERE tm.user_id = auth.uid()
        )
        AND user_id = auth.uid()
        AND status = 'pending'
    );

-- Grant permissions
GRANT ALL ON "sms_gateway"."sender_id_requests" TO authenticated;
GRANT USAGE ON SCHEMA "sms_gateway" TO authenticated;

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION "sms_gateway"."update_sender_id_requests_updated_at"()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER "set_sender_id_requests_updated_at"
    BEFORE UPDATE ON "sms_gateway"."sender_id_requests"
    FOR EACH ROW
    EXECUTE FUNCTION "sms_gateway"."update_sender_id_requests_updated_at"();

-- ============================================================================
-- Done! 
-- ============================================================================
-- Next steps:
-- 1. Run this SQL in Supabase SQL Editor
-- 2. Customers can now request Sender IDs from Settings screen
-- 3. Admin panel (future) can review and approve/reject requests
-- ============================================================================
