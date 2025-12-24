-- ============================================================================
-- USER & TENANT SETTINGS BACKUP TABLES
-- ============================================================================
-- Tables to store both user settings and tenant settings for backup to Supabase

-- ============================================================================
-- USER SETTINGS TABLE
-- ============================================================================
-- Stores per-user preferences like SMS channel, auto-start, theme, etc.
CREATE TABLE IF NOT EXISTS "sms_gateway"."user_settings" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id uuid NOT NULL REFERENCES "sms_gateway"."tenants"(id) ON DELETE CASCADE,
    
    -- SMS Preferences
    sms_channel text DEFAULT 'thisPhone' CHECK (sms_channel IN ('thisPhone', 'quickSMS')),
    api_queue_auto_start boolean DEFAULT false,
    
    -- UI Preferences
    theme_mode text DEFAULT 'light' CHECK (theme_mode IN ('light', 'dark', 'system')),
    language text DEFAULT 'en',
    
    -- Notification Preferences
    notification_on_sms_sent boolean DEFAULT true,
    notification_on_sms_failed boolean DEFAULT true,
    notification_on_quota_warning boolean DEFAULT true,
    
    -- Additional settings (JSON for extensibility)
    additional_settings jsonb DEFAULT '{}'::jsonb,
    
    -- Metadata
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    synced_at timestamp with time zone,
    
    UNIQUE(user_id, tenant_id)
);

-- Index for quick lookup
CREATE INDEX IF NOT EXISTS idx_user_settings_user_id ON "sms_gateway"."user_settings"(user_id);
CREATE INDEX IF NOT EXISTS idx_user_settings_tenant_id ON "sms_gateway"."user_settings"(tenant_id);
CREATE INDEX IF NOT EXISTS idx_user_settings_updated_at ON "sms_gateway"."user_settings"(updated_at);

-- ============================================================================
-- TENANT SETTINGS TABLE
-- ============================================================================
-- Stores tenant-wide settings like default SMS channel, quotas, etc.
CREATE TABLE IF NOT EXISTS "sms_gateway"."tenant_settings" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL UNIQUE REFERENCES "sms_gateway"."tenants"(id) ON DELETE CASCADE,
    
    -- Default SMS Settings
    default_sms_channel text DEFAULT 'thisPhone' CHECK (default_sms_channel IN ('thisPhone', 'quickSMS')),
    default_sms_sender_id text,
    
    -- Quota Settings
    daily_sms_quota integer DEFAULT 10000,
    monthly_sms_quota integer DEFAULT 100000,
    
    -- Feature Flags
    enable_bulk_sms boolean DEFAULT true,
    enable_scheduled_sms boolean DEFAULT true,
    enable_sms_groups boolean DEFAULT true,
    enable_api_access boolean DEFAULT true,
    
    -- API Settings
    api_webhook_url text,
    api_webhook_secret text,
    
    -- Billing & Plan Info
    plan_type text DEFAULT 'basic' CHECK (plan_type IN ('basic', 'pro', 'enterprise')),
    sms_cost_per_unit numeric(10, 4) DEFAULT 0.05,
    
    -- Advanced Settings
    advanced_settings jsonb DEFAULT '{}'::jsonb,
    
    -- Metadata
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    synced_at timestamp with time zone,
    
    created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Index for quick lookup
CREATE INDEX IF NOT EXISTS idx_tenant_settings_tenant_id ON "sms_gateway"."tenant_settings"(tenant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_settings_updated_at ON "sms_gateway"."tenant_settings"(updated_at);

-- ============================================================================
-- SETTINGS SYNC LOG TABLE
-- ============================================================================
-- Tracks when settings are synced for audit and debugging
CREATE TABLE IF NOT EXISTS "sms_gateway"."settings_sync_log" (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id uuid NOT NULL REFERENCES "sms_gateway"."tenants"(id) ON DELETE CASCADE,
    
    sync_type text NOT NULL CHECK (sync_type IN ('user_settings', 'tenant_settings', 'both')),
    direction text NOT NULL CHECK (direction IN ('local_to_remote', 'remote_to_local', 'bidirectional')),
    
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'success', 'failed', 'partial')),
    error_message text,
    
    settings_count integer DEFAULT 0,
    synced_fields text[], -- Array of field names that were synced
    
    created_at timestamp with time zone DEFAULT now(),
    completed_at timestamp with time zone
);

-- Index for audit trail
CREATE INDEX IF NOT EXISTS idx_settings_sync_log_user_id ON "sms_gateway"."settings_sync_log"(user_id);
CREATE INDEX IF NOT EXISTS idx_settings_sync_log_tenant_id ON "sms_gateway"."settings_sync_log"(tenant_id);
CREATE INDEX IF NOT EXISTS idx_settings_sync_log_created_at ON "sms_gateway"."settings_sync_log"(created_at DESC);

-- ============================================================================
-- TRIGGERS FOR UPDATED_AT
-- ============================================================================

-- Trigger for user_settings
CREATE OR REPLACE FUNCTION "sms_gateway"."update_user_settings_updated_at"()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_user_settings_updated_at ON "sms_gateway"."user_settings";
CREATE TRIGGER trigger_user_settings_updated_at
BEFORE UPDATE ON "sms_gateway"."user_settings"
FOR EACH ROW
EXECUTE FUNCTION "sms_gateway"."update_user_settings_updated_at"();

-- Trigger for tenant_settings
CREATE OR REPLACE FUNCTION "sms_gateway"."update_tenant_settings_updated_at"()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_tenant_settings_updated_at ON "sms_gateway"."tenant_settings";
CREATE TRIGGER trigger_tenant_settings_updated_at
BEFORE UPDATE ON "sms_gateway"."tenant_settings"
FOR EACH ROW
EXECUTE FUNCTION "sms_gateway"."update_tenant_settings_updated_at"();

-- ============================================================================
-- RLS POLICIES
-- ============================================================================

-- Enable RLS
ALTER TABLE "sms_gateway"."user_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "sms_gateway"."tenant_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "sms_gateway"."settings_sync_log" ENABLE ROW LEVEL SECURITY;

-- User Settings: Users can only see their own settings
CREATE POLICY "Users can view own settings" ON "sms_gateway"."user_settings"
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own settings" ON "sms_gateway"."user_settings"
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings" ON "sms_gateway"."user_settings"
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Tenant Settings: Users with access to tenant can view/update
CREATE POLICY "Tenant users can view tenant settings" ON "sms_gateway"."tenant_settings"
    FOR SELECT USING (
        "sms_gateway"."tenant_settings".tenant_id IN (
            SELECT tenant_id FROM "sms_gateway"."tenant_members"
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Tenant admins can update tenant settings" ON "sms_gateway"."tenant_settings"
    FOR UPDATE USING (
        "sms_gateway"."tenant_settings".tenant_id IN (
            SELECT tenant_id FROM "sms_gateway"."tenant_members"
            WHERE user_id = auth.uid()
            AND role IN ('admin', 'owner')
        )
    );

CREATE POLICY "Tenant admins can insert tenant settings" ON "sms_gateway"."tenant_settings"
    FOR INSERT WITH CHECK (
        (SELECT count(*) FROM "sms_gateway"."tenant_members"
         WHERE tenant_id = "sms_gateway"."tenant_settings".tenant_id
         AND user_id = auth.uid()
         AND role IN ('admin', 'owner')) > 0
    );

-- Settings Sync Log: Users can view their own sync logs
CREATE POLICY "Users can view own sync logs" ON "sms_gateway"."settings_sync_log"
    FOR SELECT USING (
        auth.uid() = user_id OR 
        "sms_gateway"."settings_sync_log".tenant_id IN (
            SELECT tenant_id FROM "sms_gateway"."tenant_members"
            WHERE user_id = auth.uid()
            AND role IN ('admin', 'owner')
        )
    );

-- ============================================================================
-- PUBLIC WRAPPER FUNCTIONS
-- ============================================================================

-- Function to get user settings with fallback to defaults
CREATE OR REPLACE FUNCTION "sms_gateway"."get_user_settings"(
    p_user_id uuid DEFAULT NULL,
    p_tenant_id uuid DEFAULT NULL
)
RETURNS TABLE (
    id uuid,
    user_id uuid,
    tenant_id uuid,
    sms_channel text,
    api_queue_auto_start boolean,
    theme_mode text,
    language text,
    notification_on_sms_sent boolean,
    notification_on_sms_failed boolean,
    notification_on_quota_warning boolean,
    additional_settings jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    synced_at timestamp with time zone
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = sms_gateway
AS $$
    SELECT 
        us.id,
        us.user_id,
        us.tenant_id,
        us.sms_channel,
        us.api_queue_auto_start,
        us.theme_mode,
        us.language,
        us.notification_on_sms_sent,
        us.notification_on_sms_failed,
        us.notification_on_quota_warning,
        us.additional_settings,
        us.created_at,
        us.updated_at,
        us.synced_at
    FROM user_settings us
    WHERE user_id = COALESCE(p_user_id, auth.uid())
    AND tenant_id = COALESCE(p_tenant_id, (
        SELECT id FROM tenants WHERE id = p_tenant_id LIMIT 1
    ))
$$;

-- Function to get tenant settings
CREATE OR REPLACE FUNCTION "sms_gateway"."get_tenant_settings"(
    p_tenant_id uuid
)
RETURNS TABLE (
    id uuid,
    tenant_id uuid,
    default_sms_channel text,
    default_sms_sender_id text,
    daily_sms_quota integer,
    monthly_sms_quota integer,
    enable_bulk_sms boolean,
    enable_scheduled_sms boolean,
    enable_sms_groups boolean,
    enable_api_access boolean,
    api_webhook_url text,
    plan_type text,
    sms_cost_per_unit numeric,
    advanced_settings jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone,
    synced_at timestamp with time zone
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = sms_gateway
AS $$
    SELECT 
        ts.id,
        ts.tenant_id,
        ts.default_sms_channel,
        ts.default_sms_sender_id,
        ts.daily_sms_quota,
        ts.monthly_sms_quota,
        ts.enable_bulk_sms,
        ts.enable_scheduled_sms,
        ts.enable_sms_groups,
        ts.enable_api_access,
        ts.api_webhook_url,
        ts.plan_type,
        ts.sms_cost_per_unit,
        ts.advanced_settings,
        ts.created_at,
        ts.updated_at,
        ts.synced_at
    FROM tenant_settings ts
    WHERE tenant_id = p_tenant_id
$$;

-- Function to update user settings
CREATE OR REPLACE FUNCTION "sms_gateway"."update_user_settings"(
    p_user_id uuid,
    p_tenant_id uuid,
    p_sms_channel text DEFAULT NULL,
    p_api_queue_auto_start boolean DEFAULT NULL,
    p_theme_mode text DEFAULT NULL,
    p_language text DEFAULT NULL,
    p_notification_on_sms_sent boolean DEFAULT NULL,
    p_notification_on_sms_failed boolean DEFAULT NULL,
    p_notification_on_quota_warning boolean DEFAULT NULL,
    p_additional_settings jsonb DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = sms_gateway
AS $$
DECLARE
    v_result json;
BEGIN
    INSERT INTO user_settings (
        user_id,
        tenant_id,
        sms_channel,
        api_queue_auto_start,
        theme_mode,
        language,
        notification_on_sms_sent,
        notification_on_sms_failed,
        notification_on_quota_warning,
        additional_settings
    )
    VALUES (
        p_user_id,
        p_tenant_id,
        COALESCE(p_sms_channel, 'thisPhone'),
        COALESCE(p_api_queue_auto_start, false),
        COALESCE(p_theme_mode, 'light'),
        COALESCE(p_language, 'en'),
        COALESCE(p_notification_on_sms_sent, true),
        COALESCE(p_notification_on_sms_failed, true),
        COALESCE(p_notification_on_quota_warning, true),
        COALESCE(p_additional_settings, '{}'::jsonb)
    )
    ON CONFLICT (user_id, tenant_id) 
    DO UPDATE SET
        sms_channel = COALESCE(p_sms_channel, user_settings.sms_channel),
        api_queue_auto_start = COALESCE(p_api_queue_auto_start, user_settings.api_queue_auto_start),
        theme_mode = COALESCE(p_theme_mode, user_settings.theme_mode),
        language = COALESCE(p_language, user_settings.language),
        notification_on_sms_sent = COALESCE(p_notification_on_sms_sent, user_settings.notification_on_sms_sent),
        notification_on_sms_failed = COALESCE(p_notification_on_sms_failed, user_settings.notification_on_sms_failed),
        notification_on_quota_warning = COALESCE(p_notification_on_quota_warning, user_settings.notification_on_quota_warning),
        additional_settings = COALESCE(p_additional_settings, user_settings.additional_settings);
    
    v_result := jsonb_build_object('success', true, 'message', 'Settings updated');
    RETURN v_result;
END;
$$;

-- Function to log settings sync
CREATE OR REPLACE FUNCTION "sms_gateway"."log_settings_sync"(
    p_user_id uuid,
    p_tenant_id uuid,
    p_sync_type text,
    p_direction text,
    p_status text DEFAULT 'pending',
    p_error_message text DEFAULT NULL,
    p_synced_fields text[] DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = sms_gateway
AS $$
DECLARE
    v_log_id uuid;
BEGIN
    INSERT INTO settings_sync_log (
        user_id,
        tenant_id,
        sync_type,
        direction,
        status,
        error_message,
        synced_fields,
        settings_count
    )
    VALUES (
        p_user_id,
        p_tenant_id,
        p_sync_type,
        p_direction,
        p_status,
        p_error_message,
        p_synced_fields,
        COALESCE(array_length(p_synced_fields, 1), 0)
    )
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;

-- Function to mark sync as completed
CREATE OR REPLACE FUNCTION "sms_gateway"."complete_settings_sync"(
    p_log_id uuid,
    p_status text,
    p_error_message text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = sms_gateway
AS $$
BEGIN
    UPDATE settings_sync_log
    SET 
        status = p_status,
        error_message = p_error_message,
        completed_at = now()
    WHERE id = p_log_id;
    
    RETURN jsonb_build_object('success', true, 'message', 'Sync logged');
END;
$$;

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE "sms_gateway"."user_settings" IS 'Per-user preferences and settings for SMS Gateway';
COMMENT ON TABLE "sms_gateway"."tenant_settings" IS 'Tenant-wide settings and configuration';
COMMENT ON TABLE "sms_gateway"."settings_sync_log" IS 'Audit log for settings synchronization between local and remote';
