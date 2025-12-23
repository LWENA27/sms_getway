-- ============================================================================
-- CONSOLIDATED MIGRATION V2 - SMS Gateway Multi-Tenant Setup
-- ============================================================================
-- This script works with the EXISTING remote database structure
-- It only creates what's missing (sms_gateway schema and tables)
-- 
-- Assumptions:
-- - public.products, clients, global_users, etc. already exist
-- - Only need to create sms_gateway schema and related tables
-- ============================================================================

-- ============================================================================
-- STEP 1: CREATE SMS_GATEWAY SCHEMA
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS sms_gateway;

-- ============================================================================
-- STEP 2: CREATE SMS_GATEWAY TABLES
-- ============================================================================

-- Users table (SMS Gateway users with tenant isolation)
CREATE TABLE IF NOT EXISTS sms_gateway.users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name VARCHAR(255),
  phone VARCHAR(50),
  is_active BOOLEAN DEFAULT true,
  tenant_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE
);

-- Contacts table
CREATE TABLE IF NOT EXISTS sms_gateway.contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(50) NOT NULL,
  email VARCHAR(255),
  notes TEXT,
  tenant_id UUID NOT NULL,
  user_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES sms_gateway.users(id) ON DELETE CASCADE
);

-- Groups table
CREATE TABLE IF NOT EXISTS sms_gateway.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  tenant_id UUID NOT NULL,
  user_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES sms_gateway.users(id) ON DELETE CASCADE
);

-- Group Members table
CREATE TABLE IF NOT EXISTS sms_gateway.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL,
  contact_id UUID NOT NULL,
  tenant_id UUID NOT NULL,
  added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT fk_group FOREIGN KEY (group_id) REFERENCES sms_gateway.groups(id) ON DELETE CASCADE,
  CONSTRAINT fk_contact FOREIGN KEY (contact_id) REFERENCES sms_gateway.contacts(id) ON DELETE CASCADE,
  UNIQUE(group_id, contact_id)
);

-- SMS Logs table
CREATE TABLE IF NOT EXISTS sms_gateway.sms_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_phone VARCHAR(50) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  error_message TEXT,
  sent_at TIMESTAMP WITH TIME ZONE,
  tenant_id UUID NOT NULL,
  user_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES sms_gateway.users(id) ON DELETE CASCADE
);

-- API Keys table
CREATE TABLE IF NOT EXISTS sms_gateway.api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key_hash VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  last_used_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true,
  tenant_id UUID NOT NULL,
  user_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES sms_gateway.users(id) ON DELETE CASCADE
);

-- Audit Logs table
CREATE TABLE IF NOT EXISTS sms_gateway.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  action VARCHAR(255) NOT NULL,
  table_name VARCHAR(255) NOT NULL,
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  tenant_id UUID NOT NULL,
  user_id UUID NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES sms_gateway.users(id) ON DELETE CASCADE
);

-- Settings table
CREATE TABLE IF NOT EXISTS sms_gateway.settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(255) NOT NULL,
  value TEXT,
  tenant_id UUID NOT NULL,
  user_id UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_tenant FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT fk_user FOREIGN KEY (user_id) REFERENCES sms_gateway.users(id) ON DELETE SET NULL,
  UNIQUE(tenant_id, key)
);

-- ============================================================================
-- STEP 3: CREATE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_users_tenant ON sms_gateway.users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON sms_gateway.users(email);

CREATE INDEX IF NOT EXISTS idx_contacts_tenant ON sms_gateway.contacts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_contacts_user ON sms_gateway.contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON sms_gateway.contacts(phone);

CREATE INDEX IF NOT EXISTS idx_groups_tenant ON sms_gateway.groups(tenant_id);
CREATE INDEX IF NOT EXISTS idx_groups_user ON sms_gateway.groups(user_id);

CREATE INDEX IF NOT EXISTS idx_group_members_tenant ON sms_gateway.group_members(tenant_id);
CREATE INDEX IF NOT EXISTS idx_group_members_group ON sms_gateway.group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_contact ON sms_gateway.group_members(contact_id);

CREATE INDEX IF NOT EXISTS idx_sms_logs_tenant ON sms_gateway.sms_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_logs_user ON sms_gateway.sms_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_sms_logs_status ON sms_gateway.sms_logs(status);
CREATE INDEX IF NOT EXISTS idx_sms_logs_sent_at ON sms_gateway.sms_logs(sent_at);

CREATE INDEX IF NOT EXISTS idx_api_keys_tenant ON sms_gateway.api_keys(tenant_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_user ON sms_gateway.api_keys(user_id);

CREATE INDEX IF NOT EXISTS idx_audit_logs_tenant ON sms_gateway.audit_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON sms_gateway.audit_logs(user_id);

CREATE INDEX IF NOT EXISTS idx_settings_tenant ON sms_gateway.settings(tenant_id);
CREATE INDEX IF NOT EXISTS idx_settings_tenant_key ON sms_gateway.settings(tenant_id, key);

-- ============================================================================
-- STEP 4: ENABLE ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE sms_gateway.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.sms_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.settings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 5: CREATE RLS POLICIES
-- ============================================================================

-- Users policies
DROP POLICY IF EXISTS users_tenant_isolation ON sms_gateway.users;
CREATE POLICY users_tenant_isolation ON sms_gateway.users
  USING (
    tenant_id IN (
      SELECT cpa.client_id 
      FROM public.client_product_access cpa
      WHERE cpa.user_id = auth.uid()
    )
  );

-- Contacts policies
DROP POLICY IF EXISTS contacts_tenant_isolation ON sms_gateway.contacts;
CREATE POLICY contacts_tenant_isolation ON sms_gateway.contacts
  USING (
    tenant_id IN (
      SELECT cpa.client_id 
      FROM public.client_product_access cpa
      WHERE cpa.user_id = auth.uid()
    )
  );

-- Groups policies
DROP POLICY IF EXISTS groups_tenant_isolation ON sms_gateway.groups;
CREATE POLICY groups_tenant_isolation ON sms_gateway.groups
  USING (
    tenant_id IN (
      SELECT cpa.client_id 
      FROM public.client_product_access cpa
      WHERE cpa.user_id = auth.uid()
    )
  );

-- Group Members policies
DROP POLICY IF EXISTS group_members_tenant_isolation ON sms_gateway.group_members;
CREATE POLICY group_members_tenant_isolation ON sms_gateway.group_members
  USING (
    tenant_id IN (
      SELECT cpa.client_id 
      FROM public.client_product_access cpa
      WHERE cpa.user_id = auth.uid()
    )
  );

-- SMS Logs policies
DROP POLICY IF EXISTS sms_logs_tenant_isolation ON sms_gateway.sms_logs;
CREATE POLICY sms_logs_tenant_isolation ON sms_gateway.sms_logs
  USING (
    tenant_id IN (
      SELECT cpa.client_id 
      FROM public.client_product_access cpa
      WHERE cpa.user_id = auth.uid()
    )
  );

-- API Keys policies
DROP POLICY IF EXISTS api_keys_tenant_isolation ON sms_gateway.api_keys;
CREATE POLICY api_keys_tenant_isolation ON sms_gateway.api_keys
  USING (
    tenant_id IN (
      SELECT cpa.client_id 
      FROM public.client_product_access cpa
      WHERE cpa.user_id = auth.uid()
    )
  );

-- Audit Logs policies
DROP POLICY IF EXISTS audit_logs_tenant_isolation ON sms_gateway.audit_logs;
CREATE POLICY audit_logs_tenant_isolation ON sms_gateway.audit_logs
  USING (
    tenant_id IN (
      SELECT cpa.client_id 
      FROM public.client_product_access cpa
      WHERE cpa.user_id = auth.uid()
    )
  );

-- Settings policies
DROP POLICY IF EXISTS settings_tenant_isolation ON sms_gateway.settings;
CREATE POLICY settings_tenant_isolation ON sms_gateway.settings
  USING (
    tenant_id IN (
      SELECT cpa.client_id 
      FROM public.client_product_access cpa
      WHERE cpa.user_id = auth.uid()
    )
  );

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================
-- 
-- Schema created:
--   - sms_gateway: 8 tables with tenant_id support
-- 
-- RLS policies: Multi-tenant aware (tenant_id filtering via client_product_access)
-- 
-- Next steps:
--   1. Verify with: SELECT * FROM information_schema.tables WHERE table_schema = 'sms_gateway';
--   2. Test tenant isolation
--   3. Connect Flutter app
-- ============================================================================
