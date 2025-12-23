-- Add Multi-Tenant Support to SMS Gateway Schema
-- This script adds tenant_id fields to connect SMS Gateway to the public.clients table
-- Run this AFTER executing schema_isolated.sql

-- Add tenant_id column to users table
ALTER TABLE sms_gateway.users 
ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES public.clients(id) ON DELETE CASCADE;

-- Add tenant_id column to contacts table
ALTER TABLE sms_gateway.contacts 
ADD COLUMN IF NOT EXISTS tenant_id UUID NOT NULL;

-- Add foreign key constraint for contacts.tenant_id
ALTER TABLE sms_gateway.contacts
ADD CONSTRAINT fk_contacts_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;

-- Add tenant_id column to groups table
ALTER TABLE sms_gateway.groups 
ADD COLUMN IF NOT EXISTS tenant_id UUID NOT NULL;

-- Add foreign key constraint for groups.tenant_id
ALTER TABLE sms_gateway.groups
ADD CONSTRAINT fk_groups_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;

-- Add tenant_id column to group_members table
ALTER TABLE sms_gateway.group_members 
ADD COLUMN IF NOT EXISTS tenant_id UUID NOT NULL;

-- Add foreign key constraint for group_members.tenant_id
ALTER TABLE sms_gateway.group_members
ADD CONSTRAINT fk_group_members_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;

-- Add tenant_id column to sms_logs table
ALTER TABLE sms_gateway.sms_logs 
ADD COLUMN IF NOT EXISTS tenant_id UUID NOT NULL;

-- Add foreign key constraint for sms_logs.tenant_id
ALTER TABLE sms_gateway.sms_logs
ADD CONSTRAINT fk_sms_logs_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;

-- Add tenant_id column to api_keys table
ALTER TABLE sms_gateway.api_keys 
ADD COLUMN IF NOT EXISTS tenant_id UUID NOT NULL;

-- Add foreign key constraint for api_keys.tenant_id
ALTER TABLE sms_gateway.api_keys
ADD CONSTRAINT fk_api_keys_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;

-- Add tenant_id column to audit_logs table
ALTER TABLE sms_gateway.audit_logs 
ADD COLUMN IF NOT EXISTS tenant_id UUID NOT NULL;

-- Add foreign key constraint for audit_logs.tenant_id
ALTER TABLE sms_gateway.audit_logs
ADD CONSTRAINT fk_audit_logs_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;

-- Add tenant_id column to settings table
ALTER TABLE sms_gateway.settings 
ADD COLUMN IF NOT EXISTS tenant_id UUID NOT NULL;

-- Add foreign key constraint for settings.tenant_id
ALTER TABLE sms_gateway.settings
ADD CONSTRAINT fk_settings_tenant_id FOREIGN KEY (tenant_id) REFERENCES public.clients(id) ON DELETE CASCADE;

-- Create indexes for tenant_id columns to improve query performance
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

-- DROP old RLS policies and create new multi-tenant aware policies

-- Drop old users policies
DROP POLICY IF EXISTS "Users can view their own profile" ON sms_gateway.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON sms_gateway.users;

-- Create new users policies with tenant isolation
CREATE POLICY "Users can view their own profile with tenant isolation"
  ON sms_gateway.users
  FOR SELECT
  USING (auth.uid() = id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = id AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can update their own profile with tenant isolation"
  ON sms_gateway.users
  FOR UPDATE
  USING (auth.uid() = id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = id AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Drop old contacts policies
DROP POLICY IF EXISTS "Users can view their own contacts" ON sms_gateway.contacts;
DROP POLICY IF EXISTS "Users can insert their own contacts" ON sms_gateway.contacts;
DROP POLICY IF EXISTS "Users can update their own contacts" ON sms_gateway.contacts;
DROP POLICY IF EXISTS "Users can delete their own contacts" ON sms_gateway.contacts;

-- Create new contacts policies with tenant isolation
CREATE POLICY "Users can view their tenant contacts"
  ON sms_gateway.contacts
  FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can insert their tenant contacts"
  ON sms_gateway.contacts
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can update their tenant contacts"
  ON sms_gateway.contacts
  FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can delete their tenant contacts"
  ON sms_gateway.contacts
  FOR DELETE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Drop old groups policies
DROP POLICY IF EXISTS "Users can view their own groups" ON sms_gateway.groups;
DROP POLICY IF EXISTS "Users can insert their own groups" ON sms_gateway.groups;
DROP POLICY IF EXISTS "Users can update their own groups" ON sms_gateway.groups;
DROP POLICY IF EXISTS "Users can delete their own groups" ON sms_gateway.groups;

-- Create new groups policies with tenant isolation
CREATE POLICY "Users can view their tenant groups"
  ON sms_gateway.groups
  FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can insert their tenant groups"
  ON sms_gateway.groups
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can update their tenant groups"
  ON sms_gateway.groups
  FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can delete their tenant groups"
  ON sms_gateway.groups
  FOR DELETE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Drop old group_members policies
DROP POLICY IF EXISTS "Users can view their group members" ON sms_gateway.group_members;
DROP POLICY IF EXISTS "Users can insert group members for their groups" ON sms_gateway.group_members;
DROP POLICY IF EXISTS "Users can delete group members from their groups" ON sms_gateway.group_members;

-- Create new group_members policies with tenant isolation
CREATE POLICY "Users can view their tenant group members"
  ON sms_gateway.group_members
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_id
    AND g.user_id = auth.uid()
    AND g.tenant_id = tenant_id
    AND EXISTS (SELECT 1 FROM public.client_product_access cpa 
                WHERE cpa.user_id = auth.uid() AND cpa.client_id = g.tenant_id AND cpa.product = 'sms_gateway')
  ));

CREATE POLICY "Users can insert group members for their tenant groups"
  ON sms_gateway.group_members
  FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_id
    AND g.user_id = auth.uid()
    AND g.tenant_id = tenant_id
    AND EXISTS (SELECT 1 FROM public.client_product_access cpa 
                WHERE cpa.user_id = auth.uid() AND cpa.client_id = g.tenant_id AND cpa.product = 'sms_gateway')
  ));

CREATE POLICY "Users can delete group members from their tenant groups"
  ON sms_gateway.group_members
  FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_id
    AND g.user_id = auth.uid()
    AND g.tenant_id = tenant_id
    AND EXISTS (SELECT 1 FROM public.client_product_access cpa 
                WHERE cpa.user_id = auth.uid() AND cpa.client_id = g.tenant_id AND cpa.product = 'sms_gateway')
  ));

-- Drop old sms_logs policies
DROP POLICY IF EXISTS "Users can view their own SMS logs" ON sms_gateway.sms_logs;
DROP POLICY IF EXISTS "Users can insert their own SMS logs" ON sms_gateway.sms_logs;
DROP POLICY IF EXISTS "Users can update their own SMS logs" ON sms_gateway.sms_logs;

-- Create new sms_logs policies with tenant isolation
CREATE POLICY "Users can view their tenant SMS logs"
  ON sms_gateway.sms_logs
  FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can insert their tenant SMS logs"
  ON sms_gateway.sms_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can update their tenant SMS logs"
  ON sms_gateway.sms_logs
  FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Drop old api_keys policies
DROP POLICY IF EXISTS "Users can view their own API keys" ON sms_gateway.api_keys;
DROP POLICY IF EXISTS "Users can insert their own API keys" ON sms_gateway.api_keys;
DROP POLICY IF EXISTS "Users can update their own API keys" ON sms_gateway.api_keys;
DROP POLICY IF EXISTS "Users can delete their own API keys" ON sms_gateway.api_keys;

-- Create new api_keys policies with tenant isolation
CREATE POLICY "Users can view their tenant API keys"
  ON sms_gateway.api_keys
  FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can insert their tenant API keys"
  ON sms_gateway.api_keys
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can update their tenant API keys"
  ON sms_gateway.api_keys
  FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can delete their tenant API keys"
  ON sms_gateway.api_keys
  FOR DELETE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Drop old audit_logs policy
DROP POLICY IF EXISTS "Users can view their own audit logs" ON sms_gateway.audit_logs;

-- Create new audit_logs policy with tenant isolation
CREATE POLICY "Users can view their tenant audit logs"
  ON sms_gateway.audit_logs
  FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

-- Drop old settings policies
DROP POLICY IF EXISTS "Users can view their own settings" ON sms_gateway.settings;
DROP POLICY IF EXISTS "Users can insert their own settings" ON sms_gateway.settings;
DROP POLICY IF EXISTS "Users can update their own settings" ON sms_gateway.settings;
DROP POLICY IF EXISTS "Users can delete their own settings" ON sms_gateway.settings;

-- Create new settings policies with tenant isolation
CREATE POLICY "Users can view their tenant settings"
  ON sms_gateway.settings
  FOR SELECT
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can insert their tenant settings"
  ON sms_gateway.settings
  FOR INSERT
  WITH CHECK (auth.uid() = user_id AND 
              EXISTS (SELECT 1 FROM public.client_product_access cpa 
                      WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can update their tenant settings"
  ON sms_gateway.settings
  FOR UPDATE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));

CREATE POLICY "Users can delete their tenant settings"
  ON sms_gateway.settings
  FOR DELETE
  USING (auth.uid() = user_id AND 
         EXISTS (SELECT 1 FROM public.client_product_access cpa 
                 WHERE cpa.user_id = auth.uid() AND cpa.client_id = tenant_id AND cpa.product = 'sms_gateway'));
