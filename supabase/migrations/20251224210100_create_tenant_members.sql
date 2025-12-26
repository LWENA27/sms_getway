-- ============================================================================
-- CREATE SMS_GATEWAY TENANT_MEMBERS TABLE
-- ============================================================================
-- This migration creates the tenant_members table for tenant member management
-- Required by RLS policies in the settings tables

CREATE TABLE IF NOT EXISTS "sms_gateway"."tenant_members" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL REFERENCES "sms_gateway"."tenants"(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES "auth"."users"(id) ON DELETE CASCADE,
    role text NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    UNIQUE(tenant_id, user_id)
);

ALTER TABLE "sms_gateway"."tenant_members" OWNER TO "postgres";

-- Create indexes
CREATE INDEX IF NOT EXISTS "idx_sms_gateway_tenant_members_tenant_id" ON "sms_gateway"."tenant_members"(tenant_id);
CREATE INDEX IF NOT EXISTS "idx_sms_gateway_tenant_members_user_id" ON "sms_gateway"."tenant_members"(user_id);
CREATE INDEX IF NOT EXISTS "idx_sms_gateway_tenant_members_role" ON "sms_gateway"."tenant_members"(role);

COMMENT ON TABLE "sms_gateway"."tenant_members" IS 'SMS Gateway Tenant Members - tracks user membership and roles';
