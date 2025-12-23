-- SMS Gateway Database Schema
-- Supabase PostgreSQL

-- ===== USERS TABLE =====
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  name TEXT,
  phone_number TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Policies for users
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- ===== CONTACTS TABLE =====
CREATE TABLE IF NOT EXISTS contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, phone_number)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_contacts_user_id ON contacts(user_id);
CREATE INDEX IF NOT EXISTS idx_contacts_phone ON contacts(phone_number);

-- Enable RLS
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;

-- Policies for contacts
CREATE POLICY "Users can view own contacts" ON contacts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own contacts" ON contacts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own contacts" ON contacts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own contacts" ON contacts
  FOR DELETE USING (auth.uid() = user_id);

-- ===== GROUPS TABLE =====
CREATE TABLE IF NOT EXISTS groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  group_name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, group_name)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_groups_user_id ON groups(user_id);

-- Enable RLS
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;

-- Policies for groups
CREATE POLICY "Users can view own groups" ON groups
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own groups" ON groups
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own groups" ON groups
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own groups" ON groups
  FOR DELETE USING (auth.uid() = user_id);

-- ===== GROUP_MEMBERS TABLE =====
CREATE TABLE IF NOT EXISTS group_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  added_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(group_id, contact_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_group_members_group_id ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_group_members_contact_id ON group_members(contact_id);

-- Enable RLS
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;

-- Policies for group_members
CREATE POLICY "Users can view own group members" ON group_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM groups WHERE groups.id = group_members.group_id AND groups.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can add members to own groups" ON group_members
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM groups WHERE groups.id = group_members.group_id AND groups.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can remove members from own groups" ON group_members
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM groups WHERE groups.id = group_members.group_id AND groups.user_id = auth.uid()
    )
  );

-- ===== SMS_LOGS TABLE =====
CREATE TABLE IF NOT EXISTS sms_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender TEXT NOT NULL,
  recipient TEXT NOT NULL,
  message TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'delivered', 'pending')),
  error_message TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sms_logs_user_id ON sms_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_sms_logs_status ON sms_logs(status);
CREATE INDEX IF NOT EXISTS idx_sms_logs_created_at ON sms_logs(created_at DESC);

-- Enable RLS
ALTER TABLE sms_logs ENABLE ROW LEVEL SECURITY;

-- Policies for sms_logs
CREATE POLICY "Users can view own SMS logs" ON sms_logs
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own SMS logs" ON sms_logs
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ===== API_KEYS TABLE (Phase 2) =====
CREATE TABLE IF NOT EXISTS api_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  key TEXT NOT NULL UNIQUE,
  name TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'revoked')),
  last_used_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX IF NOT EXISTS idx_api_keys_key ON api_keys(key);

-- Enable RLS
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- Policies for api_keys
CREATE POLICY "Users can view own API keys" ON api_keys
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own API keys" ON api_keys
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ===== AUDIT_LOGS TABLE (Optional, for compliance) =====
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  resource_type TEXT,
  resource_id TEXT,
  details JSONB,
  ip_address TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);

-- ===== FUNCTION: Update updated_at timestamp =====
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- ===== TRIGGERS: Update updated_at =====
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contacts_updated_at BEFORE UPDATE ON contacts
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON groups
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sms_logs_updated_at BEFORE UPDATE ON sms_logs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ===== STORED PROCEDURE: Get user SMS statistics =====
CREATE OR REPLACE FUNCTION get_sms_stats(p_user_id UUID, p_days INT DEFAULT 7)
RETURNS TABLE(
  total_sms BIGINT,
  sent_sms BIGINT,
  failed_sms BIGINT,
  pending_sms BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*) FILTER (WHERE created_at >= NOW() - INTERVAL '1 day' * p_days),
    COUNT(*) FILTER (WHERE status = 'sent' AND created_at >= NOW() - INTERVAL '1 day' * p_days),
    COUNT(*) FILTER (WHERE status = 'failed' AND created_at >= NOW() - INTERVAL '1 day' * p_days),
    COUNT(*) FILTER (WHERE status = 'pending' AND created_at >= NOW() - INTERVAL '1 day' * p_days)
  FROM sms_logs
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ===== COMMENTS =====
COMMENT ON TABLE users IS 'Store user accounts and profile information';
COMMENT ON TABLE contacts IS 'Store user contacts for SMS sending';
COMMENT ON TABLE groups IS 'Store contact groups for bulk SMS';
COMMENT ON TABLE group_members IS 'Association between groups and contacts';
COMMENT ON TABLE sms_logs IS 'Log of all SMS sent through the system';
COMMENT ON TABLE api_keys IS 'API keys for external integrations (Phase 2)';
COMMENT ON TABLE audit_logs IS 'Audit trail for compliance and monitoring';
