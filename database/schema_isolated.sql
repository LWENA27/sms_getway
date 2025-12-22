-- SMS Gateway Schema - Isolated Database Schema
-- This schema contains all tables for the SMS Gateway application
-- Complete data isolation from other products using the same Supabase instance

-- Create dedicated schema
CREATE SCHEMA IF NOT EXISTS sms_gateway;

-- Users table (stored in SMS Gateway schema)
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

-- Group Members table (junction table)
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
  status VARCHAR(50) DEFAULT 'pending', -- sent, failed, delivered, pending
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

-- Create indexes for better performance
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

-- Enable RLS (Row Level Security)
ALTER TABLE sms_gateway.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.sms_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_gateway.settings ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Users table
CREATE POLICY "Users can view their own profile"
  ON sms_gateway.users
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON sms_gateway.users
  FOR UPDATE
  USING (auth.uid() = id);

-- RLS Policies for Contacts table
CREATE POLICY "Users can view their own contacts"
  ON sms_gateway.contacts
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own contacts"
  ON sms_gateway.contacts
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own contacts"
  ON sms_gateway.contacts
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own contacts"
  ON sms_gateway.contacts
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for Groups table
CREATE POLICY "Users can view their own groups"
  ON sms_gateway.groups
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own groups"
  ON sms_gateway.groups
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own groups"
  ON sms_gateway.groups
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own groups"
  ON sms_gateway.groups
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for Group Members table
CREATE POLICY "Users can view their group members"
  ON sms_gateway.group_members
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_members.group_id
    AND g.user_id = auth.uid()
  ));

CREATE POLICY "Users can insert group members for their groups"
  ON sms_gateway.group_members
  FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_id
    AND g.user_id = auth.uid()
  ));

CREATE POLICY "Users can delete group members from their groups"
  ON sms_gateway.group_members
  FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM sms_gateway.groups g
    WHERE g.id = group_id
    AND g.user_id = auth.uid()
  ));

-- RLS Policies for SMS Logs table
CREATE POLICY "Users can view their own SMS logs"
  ON sms_gateway.sms_logs
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own SMS logs"
  ON sms_gateway.sms_logs
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own SMS logs"
  ON sms_gateway.sms_logs
  FOR UPDATE
  USING (auth.uid() = user_id);

-- RLS Policies for API Keys table
CREATE POLICY "Users can view their own API keys"
  ON sms_gateway.api_keys
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own API keys"
  ON sms_gateway.api_keys
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own API keys"
  ON sms_gateway.api_keys
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own API keys"
  ON sms_gateway.api_keys
  FOR DELETE
  USING (auth.uid() = user_id);

-- RLS Policies for Audit Logs table
CREATE POLICY "Users can view their own audit logs"
  ON sms_gateway.audit_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- RLS Policies for Settings table
CREATE POLICY "Users can view their own settings"
  ON sms_gateway.settings
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings"
  ON sms_gateway.settings
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings"
  ON sms_gateway.settings
  FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own settings"
  ON sms_gateway.settings
  FOR DELETE
  USING (auth.uid() = user_id);

-- Create trigger for updating timestamps
CREATE OR REPLACE FUNCTION sms_gateway.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON sms_gateway.users
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON sms_gateway.contacts
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON sms_gateway.groups
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

CREATE TRIGGER update_sms_logs_updated_at BEFORE UPDATE ON sms_gateway.sms_logs
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

CREATE TRIGGER update_api_keys_updated_at BEFORE UPDATE ON sms_gateway.api_keys
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();

CREATE TRIGGER update_settings_updated_at BEFORE UPDATE ON sms_gateway.settings
  FOR EACH ROW EXECUTE FUNCTION sms_gateway.update_updated_at_column();
