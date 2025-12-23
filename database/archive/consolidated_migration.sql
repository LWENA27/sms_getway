-- ============================================================================
-- CONSOLIDATED MIGRATION - SMS Gateway Multi-Tenant Setup
-- ============================================================================
-- This script consolidates all necessary SQL files in the correct order
-- Run this on a CLEAN database or after resetting
-- 
-- Execution order:
-- 1. Drop existing schemas and tables (clean slate)
-- 2. Create public control plane tables
-- 3. Create sms_gateway schema with tables
-- 4. Add basic RLS policies (single-tenant)
-- 5. Add tenant_id columns and multi-tenant RLS policies
-- ============================================================================

\echo '============================================================================'
\echo 'SMS Gateway Multi-Tenant Migration - Starting'
\echo '============================================================================'

-- ============================================================================
-- STEP 0: CLEAN SLATE (Optional - comment out if you want to keep existing data)
-- ============================================================================

\echo 'Step 0: Cleaning existing schemas...'

-- Uncomment these lines if you want a complete reset:
-- DROP SCHEMA IF EXISTS sms_gateway CASCADE;
-- DROP TABLE IF EXISTS public.client_product_access CASCADE;
-- DROP TABLE IF EXISTS public.product_usage_stats CASCADE;
-- DROP TABLE IF EXISTS public.product_subscriptions CASCADE;
-- DROP TABLE IF EXISTS public.global_users CASCADE;
-- DROP TABLE IF EXISTS public.clients CASCADE;
-- DROP TABLE IF EXISTS public.products CASCADE;

\echo 'Step 0: Complete (or skipped)'

-- ============================================================================
-- STEP 1: CREATE PUBLIC SCHEMA CONTROL PLANE
-- ============================================================================

\echo 'Step 1: Creating public schema control plane...'

-- Products table (catalog of all SaaS products)
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  slug VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  status VARCHAR(50) DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Clients table (organizations/companies using your products)
CREATE TABLE IF NOT EXISTS public.clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  email VARCHAR(255),
  phone VARCHAR(20),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100),
  postal_code VARCHAR(20),
  subscription_status VARCHAR(50) DEFAULT 'active',
  monthly_limit INTEGER DEFAULT 1000,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Global Users table (all users across all products)
CREATE TABLE IF NOT EXISTS public.global_users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255),
  avatar_url TEXT,
  phone VARCHAR(20),
  role VARCHAR(50) DEFAULT 'user',
  status VARCHAR(50) DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Product Subscriptions table
CREATE TABLE IF NOT EXISTS public.product_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  subscription_tier VARCHAR(50) DEFAULT 'basic',
  status VARCHAR(50) DEFAULT 'active',
  trial_ends_at TIMESTAMP WITH TIME ZONE,
  billing_cycle_start TIMESTAMP WITH TIME ZONE,
  billing_cycle_end TIMESTAMP WITH TIME ZONE,
  api_quota_limit INTEGER DEFAULT 10000,
  api_quota_used INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(client_id, product_id)
);

-- Client Product Access table
CREATE TABLE IF NOT EXISTS public.client_product_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.global_users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  product VARCHAR(100) NOT NULL,
  role VARCHAR(50) DEFAULT 'user',
  permissions JSONB DEFAULT '{}',
  status VARCHAR(50) DEFAULT 'active',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, client_id, product)
);

-- Product Usage Stats table
CREATE TABLE IF NOT EXISTS public.product_usage_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  product VARCHAR(100) NOT NULL,
  metric_name VARCHAR(100) NOT NULL,
  metric_value INTEGER DEFAULT 0,
  stat_date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(client_id, product, metric_name, stat_date)
);

-- Create indexes for public schema
CREATE INDEX IF NOT EXISTS idx_products_slug ON public.products(slug);
CREATE INDEX IF NOT EXISTS idx_products_status ON public.products(status);
CREATE INDEX IF NOT EXISTS idx_clients_slug ON public.clients(slug);
CREATE INDEX IF NOT EXISTS idx_clients_subscription_status ON public.clients(subscription_status);
CREATE INDEX IF NOT EXISTS idx_global_users_email ON public.global_users(email);
CREATE INDEX IF NOT EXISTS idx_global_users_status ON public.global_users(status);
CREATE INDEX IF NOT EXISTS idx_product_subscriptions_client ON public.product_subscriptions(client_id);
CREATE INDEX IF NOT EXISTS idx_product_subscriptions_product ON public.product_subscriptions(product_id);
CREATE INDEX IF NOT EXISTS idx_product_subscriptions_status ON public.product_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_product_subscriptions_client_product ON public.product_subscriptions(client_id, product_id);
CREATE INDEX IF NOT EXISTS idx_client_product_access_user ON public.client_product_access(user_id);
CREATE INDEX IF NOT EXISTS idx_client_product_access_client ON public.client_product_access(client_id);
CREATE INDEX IF NOT EXISTS idx_client_product_access_product ON public.client_product_access(product);
CREATE INDEX IF NOT EXISTS idx_client_product_access_user_client_product ON public.client_product_access(user_id, client_id, product);
CREATE INDEX IF NOT EXISTS idx_product_usage_stats_client ON public.product_usage_stats(client_id);
CREATE INDEX IF NOT EXISTS idx_product_usage_stats_product ON public.product_usage_stats(product);
CREATE INDEX IF NOT EXISTS idx_product_usage_stats_date ON public.product_usage_stats(stat_date);

-- Enable RLS
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.global_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_product_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_usage_stats ENABLE ROW LEVEL SECURITY;

-- RLS Policies for public schema
DROP POLICY IF EXISTS "Anyone can view products" ON public.products;
CREATE POLICY "Anyone can view products"
  ON public.products
  FOR SELECT
  USING (status = 'active');

DROP POLICY IF EXISTS "Users can view clients they have access to" ON public.clients;
CREATE POLICY "Users can view clients they have access to"
  ON public.clients
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.client_product_access cpa
    WHERE cpa.client_id = id AND cpa.user_id = auth.uid()
  ));

DROP POLICY IF EXISTS "Users can view their own global profile" ON public.global_users;
CREATE POLICY "Users can view their own global profile"
  ON public.global_users
  FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can view their client product access" ON public.client_product_access;
CREATE POLICY "Users can view their client product access"
  ON public.client_product_access
  FOR SELECT
  USING (auth.uid() = user_id);

\echo 'Step 1: Public schema control plane created'

-- ============================================================================
-- STEP 2: CREATE SMS GATEWAY SCHEMA
-- ============================================================================

\echo 'Step 2: Creating sms_gateway schema...'

CREATE SCHEMA IF NOT EXISTS sms_gateway;

-- Users table
CREATE TABLE IF NOT EXISTS sms_gateway.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255),
  phone_number VARCHAR(20),
  role VARCHAR(50) DEFAULT 'user',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Contacts table
CREATE TABLE IF NOT EXISTS sms_gateway.contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES sms_gateway.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  phone_number VARCHAR(20) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Groups table
CREATE TABLE IF NOT EXISTS sms_gateway.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES sms_gateway.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Group Members table
CREATE TABLE IF NOT EXISTS sms_gateway.group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES sms_gateway.groups(id) ON DELETE CASCADE,
  contact_id UUID NOT NULL REFERENCES sms_gateway.contacts(id) ON DELETE CASCADE,
  added_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(group_id, contact_id)
);

-- SMS Logs table
CREATE TABLE IF NOT EXISTS sms_gateway.sms_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES sms_gateway.users(id) ON DELETE CASCADE,
  contact_id UUID REFERENCES sms_gateway.contacts(id) ON DELETE SET NULL,
  phone_number VARCHAR(20) NOT NULL,
  message TEXT NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  sent_at TIMESTAMP WITH TIME ZONE,
  error_message TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- API Keys table
CREATE TABLE IF NOT EXISTS sms_gateway.api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES sms_gateway.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  key_hash VARCHAR(255) NOT NULL UNIQUE,
  last_used TIMESTAMP WITH TIME ZONE,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Audit Logs table
CREATE TABLE IF NOT EXISTS sms_gateway.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES sms_gateway.users(id) ON DELETE CASCADE,
  action VARCHAR(100) NOT NULL,
  table_name VARCHAR(100),
  record_id UUID,
  old_values JSONB,
  new_values JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Settings table
CREATE TABLE IF NOT EXISTS sms_gateway.settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES sms_gateway.users(id) ON DELETE CASCADE,
  setting_key VARCHAR(255) NOT NULL,
  setting_value JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, setting_key)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_sms_gateway_contacts_user_id ON sms_gateway.contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_groups_user_id ON sms_gateway.groups(user_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_group_members_group_id ON sms_gateway.group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_group_members_contact_id ON sms_gateway.group_members(contact_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_sms_logs_user_id ON sms_gateway.sms_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_sms_logs_status ON sms_gateway.sms_logs(status);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_sms_logs_created_at ON sms_gateway.sms_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_api_keys_user_id ON sms_gateway.api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_audit_logs_user_id ON sms_gateway.audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_settings_user_id ON sms_gateway.settings(user_id);

-- Enable RLS
ALTER TABLE sms_gateway.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.sms_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.settings ENABLE ROW LEVEL SECURITY;

-- Create trigger function
CREATE OR REPLACE FUNCTION sms_gateway.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON sms_gateway.users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON sms_gateway.users
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

DROP TRIGGER IF EXISTS update_contacts_updated_at ON sms_gateway.contacts;
CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON sms_gateway.contacts
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

DROP TRIGGER IF EXISTS update_groups_updated_at ON sms_gateway.groups;
CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON sms_gateway.groups
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

DROP TRIGGER IF EXISTS update_sms_logs_updated_at ON sms_gateway.sms_logs;
CREATE TRIGGER update_sms_logs_updated_at BEFORE UPDATE ON sms_gateway.sms_logs
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

DROP TRIGGER IF EXISTS update_settings_updated_at ON sms_gateway.settings;
CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON sms_gateway.settings
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

\echo 'Step 2: SMS Gateway schema created'

-- ============================================================================
-- STEP 3: ADD BASIC RLS POLICIES (Single-Tenant)
-- ============================================================================

\echo 'Step 3: Adding basic RLS policies...'

-- Users policies
DROP POLICY IF EXISTS "Users can view their own profile" ON sms_gateway.users;
CREATE POLICY "Users can view their own profile"
  ON sms_gateway.users FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update their own profile" ON sms_gateway.users;
CREATE POLICY "Users can update their own profile"
  ON sms_gateway.users FOR UPDATE USING (auth.uid() = id);

-- Contacts policies
DROP POLICY IF EXISTS "Users can view their own contacts" ON sms_gateway.contacts;
CREATE POLICY "Users can view their own contacts"
  ON sms_gateway.contacts FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own contacts" ON sms_gateway.contacts;
CREATE POLICY "Users can insert their own contacts"
  ON sms_gateway.contacts FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own contacts" ON sms_gateway.contacts;
CREATE POLICY "Users can update their own contacts"
  ON sms_gateway.contacts FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own contacts" ON sms_gateway.contacts;
CREATE POLICY "Users can delete their own contacts"
  ON sms_gateway.contacts FOR DELETE USING (auth.uid() = user_id);

-- Groups policies
DROP POLICY IF EXISTS "Users can view their own groups" ON sms_gateway.groups;
CREATE POLICY "Users can view their own groups"
  ON sms_gateway.groups FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own groups" ON sms_gateway.groups;
CREATE POLICY "Users can insert their own groups"
  ON sms_gateway.groups FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own groups" ON sms_gateway.groups;
CREATE POLICY "Users can update their own groups"
  ON sms_gateway.groups FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own groups" ON sms_gateway.groups;
CREATE POLICY "Users can delete their own groups"
  ON sms_gateway.groups FOR DELETE USING (auth.uid() = user_id);

-- Group members policies
DROP POLICY IF EXISTS "Users can view their group members" ON sms_gateway.group_members;
CREATE POLICY "Users can view their group members"
  ON sms_gateway.group_members FOR SELECT
  USING (EXISTS (SELECT 1 FROM sms_gateway.groups WHERE id = group_id AND user_id = auth.uid()));

DROP POLICY IF EXISTS "Users can insert group members for their groups" ON sms_gateway.group_members;
CREATE POLICY "Users can insert group members for their groups"
  ON sms_gateway.group_members FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM sms_gateway.groups WHERE id = group_id AND user_id = auth.uid()));

DROP POLICY IF EXISTS "Users can delete group members from their groups" ON sms_gateway.group_members;
CREATE POLICY "Users can delete group members from their groups"
  ON sms_gateway.group_members FOR DELETE
  USING (EXISTS (SELECT 1 FROM sms_gateway.groups WHERE id = group_id AND user_id = auth.uid()));

-- SMS logs policies
DROP POLICY IF EXISTS "Users can view their own SMS logs" ON sms_gateway.sms_logs;
CREATE POLICY "Users can view their own SMS logs"
  ON sms_gateway.sms_logs FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own SMS logs" ON sms_gateway.sms_logs;
CREATE POLICY "Users can insert their own SMS logs"
  ON sms_gateway.sms_logs FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own SMS logs" ON sms_gateway.sms_logs;
CREATE POLICY "Users can update their own SMS logs"
  ON sms_gateway.sms_logs FOR UPDATE USING (auth.uid() = user_id);

-- API keys policies
DROP POLICY IF EXISTS "Users can view their own API keys" ON sms_gateway.api_keys;
CREATE POLICY "Users can view their own API keys"
  ON sms_gateway.api_keys FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own API keys" ON sms_gateway.api_keys;
CREATE POLICY "Users can insert their own API keys"
  ON sms_gateway.api_keys FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own API keys" ON sms_gateway.api_keys;
CREATE POLICY "Users can update their own API keys"
  ON sms_gateway.api_keys FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own API keys" ON sms_gateway.api_keys;
CREATE POLICY "Users can delete their own API keys"
  ON sms_gateway.api_keys FOR DELETE USING (auth.uid() = user_id);

-- Audit logs policies
DROP POLICY IF EXISTS "Users can view their own audit logs" ON sms_gateway.audit_logs;
CREATE POLICY "Users can view their own audit logs"
  ON sms_gateway.audit_logs FOR SELECT USING (auth.uid() = user_id);

-- Settings policies
DROP POLICY IF EXISTS "Users can view their own settings" ON sms_gateway.settings;
CREATE POLICY "Users can view their own settings"
  ON sms_gateway.settings FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own settings" ON sms_gateway.settings;
CREATE POLICY "Users can insert their own settings"
  ON sms_gateway.settings FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own settings" ON sms_gateway.settings;
CREATE POLICY "Users can update their own settings"
  ON sms_gateway.settings FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own settings" ON sms_gateway.settings;
CREATE POLICY "Users can delete their own settings"
  ON sms_gateway.settings FOR DELETE USING (auth.uid() = user_id);

\echo 'Step 3: Basic RLS policies created'

-- ============================================================================
-- STEP 4: ADD MULTI-TENANT SUPPORT (tenant_id columns)
-- ============================================================================

\echo 'Step 4: Adding tenant_id columns...'

-- Add tenant_id columns
ALTER TABLE sms_gateway.users ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.clients(id) ON DELETE CASCADE;
ALTER TABLE sms_gateway.contacts ADD COLUMN IF NOT EXISTS tenant_id UUID;
ALTER TABLE sms_gateway.groups ADD COLUMN IF NOT EXISTS tenant_id UUID;
ALTER TABLE sms_gateway.group_members ADD COLUMN IF NOT EXISTS tenant_id UUID;
ALTER TABLE sms_gateway.sms_logs ADD COLUMN IF NOT EXISTS tenant_id UUID;
ALTER TABLE sms_gateway.api_keys ADD COLUMN IF NOT EXISTS tenant_id UUID;
ALTER TABLE sms_gateway.audit_logs ADD COLUMN IF NOT EXISTS tenant_id UUID;
ALTER TABLE sms_gateway.settings ADD COLUMN IF NOT EXISTS tenant_id UUID;

-- Add foreign key constraints
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_contacts_tenant_id'
    ) THEN
        ALTER TABLE sms_gateway.contacts
        ADD CONSTRAINT fk_contacts_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_groups_tenant_id'
    ) THEN
        ALTER TABLE sms_gateway.groups
        ADD CONSTRAINT fk_groups_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_group_members_tenant_id'
    ) THEN
        ALTER TABLE sms_gateway.group_members
        ADD CONSTRAINT fk_group_members_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_sms_logs_tenant_id'
    ) THEN
        ALTER TABLE sms_gateway.sms_logs
        ADD CONSTRAINT fk_sms_logs_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_api_keys_tenant_id'
    ) THEN
        ALTER TABLE sms_gateway.api_keys
        ADD CONSTRAINT fk_api_keys_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_audit_logs_tenant_id'
    ) THEN
        ALTER TABLE sms_gateway.audit_logs
        ADD CONSTRAINT fk_audit_logs_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_settings_tenant_id'
    ) THEN
        ALTER TABLE sms_gateway.settings
        ADD CONSTRAINT fk_settings_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Create indexes for tenant_id columns
CREATE INDEX IF NOT EXISTS idx_sms_gateway_users_tenant_id ON sms_gateway.users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_contacts_tenant_id ON sms_gateway.contacts(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_contacts_user_tenant ON sms_gateway.contacts(user_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_groups_tenant_id ON sms_gateway.groups(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_groups_user_tenant ON sms_gateway.groups(user_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_group_members_tenant_id ON sms_gateway.group_members(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_sms_logs_tenant_id ON sms_gateway.sms_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_sms_logs_user_tenant ON sms_gateway.sms_logs(user_id, tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_api_keys_tenant_id ON sms_gateway.api_keys(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_audit_logs_tenant_id ON sms_gateway.audit_logs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_sms_gateway_settings_tenant_id ON sms_gateway.settings(tenant_id);

\echo 'Step 4: tenant_id columns added'

-- ============================================================================
-- STEP 5: UPDATE RLS POLICIES TO BE TENANT-AWARE
-- ============================================================================

\echo 'Step 5: Updating RLS policies to be tenant-aware...'

-- Drop old policies and create tenant-aware ones
-- Users policies
DROP POLICY IF EXISTS "Users can view their own profile" ON sms_gateway.users;
CREATE POLICY "Users can view their own profile with tenant isolation"
  ON sms_gateway.users FOR SELECT
  USING (auth.uid() = id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = id AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can update their own profile" ON sms_gateway.users;
CREATE POLICY "Users can update their own profile with tenant isolation"
  ON sms_gateway.users FOR UPDATE
  USING (auth.uid() = id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = id AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Contacts policies
DROP POLICY IF EXISTS "Users can view their own contacts" ON sms_gateway.contacts;
CREATE POLICY "Users can view their tenant contacts"
  ON sms_gateway.contacts FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can insert their own contacts" ON sms_gateway.contacts;
CREATE POLICY "Users can insert their tenant contacts"
  ON sms_gateway.contacts FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can update their own contacts" ON sms_gateway.contacts;
CREATE POLICY "Users can update their tenant contacts"
  ON sms_gateway.contacts FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can delete their own contacts" ON sms_gateway.contacts;
CREATE POLICY "Users can delete their tenant contacts"
  ON sms_gateway.contacts FOR DELETE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Groups policies
DROP POLICY IF EXISTS "Users can view their own groups" ON sms_gateway.groups;
CREATE POLICY "Users can view their tenant groups"
  ON sms_gateway.groups FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can insert their own groups" ON sms_gateway.groups;
CREATE POLICY "Users can insert their tenant groups"
  ON sms_gateway.groups FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can update their own groups" ON sms_gateway.groups;
CREATE POLICY "Users can update their tenant groups"
  ON sms_gateway.groups FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can delete their own groups" ON sms_gateway.groups;
CREATE POLICY "Users can delete their tenant groups"
  ON sms_gateway.groups FOR DELETE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Group members policies (tenant-aware)
DROP POLICY IF EXISTS "Users can view their group members" ON sms_gateway.group_members;
CREATE POLICY "Users can view their tenant group members"
  ON sms_gateway.group_members FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_id AND g.user_id = auth.uid() AND g.tenant_id = tenant_id
    AND EXISTS (SELECT 1 FROM public.client_product_access cpa 
                WHERE cpa.user_id = auth.uid() AND cpa.client_id = g.tenant_id AND cpa.product = 'sms_gateway')
  ));

DROP POLICY IF EXISTS "Users can insert group members for their groups" ON sms_gateway.group_members;
CREATE POLICY "Users can insert group members for their tenant groups"
  ON sms_gateway.group_members FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_id AND g.user_id = auth.uid() AND g.tenant_id = tenant_id
    AND EXISTS (SELECT 1 FROM public.client_product_access cpa 
                WHERE cpa.user_id = auth.uid() AND cpa.client_id = g.tenant_id AND cpa.product = 'sms_gateway')
  ));

DROP POLICY IF EXISTS "Users can delete group members from their groups" ON sms_gateway.group_members;
CREATE POLICY "Users can delete group members from their tenant groups"
  ON sms_gateway.group_members FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_id AND g.user_id = auth.uid() AND g.tenant_id = tenant_id
    AND EXISTS (SELECT 1 FROM public.client_product_access cpa 
                WHERE cpa.user_id = auth.uid() AND cpa.client_id = g.tenant_id AND cpa.product = 'sms_gateway')
  ));

-- SMS logs policies
DROP POLICY IF EXISTS "Users can view their own SMS logs" ON sms_gateway.sms_logs;
CREATE POLICY "Users can view their tenant SMS logs"
  ON sms_gateway.sms_logs FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can insert their own SMS logs" ON sms_gateway.sms_logs;
CREATE POLICY "Users can insert their tenant SMS logs"
  ON sms_gateway.sms_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can update their own SMS logs" ON sms_gateway.sms_logs;
CREATE POLICY "Users can update their tenant SMS logs"
  ON sms_gateway.sms_logs FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- API keys policies
DROP POLICY IF EXISTS "Users can view their own API keys" ON sms_gateway.api_keys;
CREATE POLICY "Users can view their tenant API keys"
  ON sms_gateway.api_keys FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can insert their own API keys" ON sms_gateway.api_keys;
CREATE POLICY "Users can insert their tenant API keys"
  ON sms_gateway.api_keys FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can update their own API keys" ON sms_gateway.api_keys;
CREATE POLICY "Users can update their tenant API keys"
  ON sms_gateway.api_keys FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can delete their own API keys" ON sms_gateway.api_keys;
CREATE POLICY "Users can delete their tenant API keys"
  ON sms_gateway.api_keys FOR DELETE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Audit logs policies
DROP POLICY IF EXISTS "Users can view their own audit logs" ON sms_gateway.audit_logs;
CREATE POLICY "Users can view their tenant audit logs"
  ON sms_gateway.audit_logs FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Settings policies
DROP POLICY IF EXISTS "Users can view their own settings" ON sms_gateway.settings;
CREATE POLICY "Users can view their tenant settings"
  ON sms_gateway.settings FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can insert their own settings" ON sms_gateway.settings;
CREATE POLICY "Users can insert their tenant settings"
  ON sms_gateway.settings FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can update their own settings" ON sms_gateway.settings;
CREATE POLICY "Users can update their tenant settings"
  ON sms_gateway.settings FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

DROP POLICY IF EXISTS "Users can delete their own settings" ON sms_gateway.settings;
CREATE POLICY "Users can delete their tenant settings"
  ON sms_gateway.settings FOR DELETE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

\echo 'Step 5: Tenant-aware RLS policies created'

-- ============================================================================
-- COMPLETE
-- ============================================================================

\echo '============================================================================'
\echo 'Migration Complete!'
\echo '============================================================================'
\echo ''
\echo 'Schema created:'
\echo '  - public: Control plane tables (clients, global_users, client_product_access, etc.)'
\echo '  - sms_gateway: SMS Gateway tables with tenant_id support'
\echo ''
\echo 'RLS policies: Multi-tenant aware (tenant_id + user_id filtering)'
\echo ''
\echo 'Next steps:'
\echo '  1. Insert test data or connect your Flutter app'
\echo '  2. Create initial client and users'
\echo '  3. Test queries with tenant isolation'
\echo ''
\echo 'To push to remote:'
\echo '  supabase db push'
\echo '============================================================================'
