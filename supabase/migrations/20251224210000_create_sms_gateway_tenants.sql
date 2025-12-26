-- ============================================================================
-- CREATE SMS_GATEWAY TENANTS TABLE
-- ============================================================================
-- This migration creates the tenants table for the sms_gateway schema
-- It's required by the user_settings and tenant_settings tables

CREATE TABLE IF NOT EXISTS "sms_gateway"."tenants" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    slug text UNIQUE NOT NULL,
    status text DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE "sms_gateway"."tenants" OWNER TO "postgres";

-- Create indexes
CREATE INDEX IF NOT EXISTS "idx_sms_gateway_tenants_slug" ON "sms_gateway"."tenants"(slug);
CREATE INDEX IF NOT EXISTS "idx_sms_gateway_tenants_status" ON "sms_gateway"."tenants"(status);

COMMENT ON TABLE "sms_gateway"."tenants" IS 'SMS Gateway Tenants (Multi-tenant support)';
