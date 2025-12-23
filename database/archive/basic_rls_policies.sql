-- Basic RLS Policies for SMS Gateway Schema
-- Run this AFTER schema_isolated.sql and BEFORE add_multi_tenant_support.sql
-- These are basic policies WITHOUT tenant isolation (tenant_id will be added later)

-- ============================================================================
-- USERS POLICIES
-- ============================================================================

CREATE POLICY "Users can view their own profile"
  ON sms_gateway.users
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON sms_gateway.users
  FOR UPDATE
  USING (auth.uid() = id);

-- ============================================================================
-- CONTACTS POLICIES
-- ============================================================================

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

-- ============================================================================
-- GROUPS POLICIES
-- ============================================================================

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

-- ============================================================================
-- GROUP MEMBERS POLICIES
-- ============================================================================

CREATE POLICY "Users can view their group members"
  ON sms_gateway.group_members
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM sms_gateway.groups
    WHERE id = group_id AND user_id = auth.uid()
  ));

CREATE POLICY "Users can insert group members for their groups"
  ON sms_gateway.group_members
  FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM sms_gateway.groups
    WHERE id = group_id AND user_id = auth.uid()
  ));

CREATE POLICY "Users can delete group members from their groups"
  ON sms_gateway.group_members
  FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM sms_gateway.groups
    WHERE id = group_id AND user_id = auth.uid()
  ));

-- ============================================================================
-- SMS LOGS POLICIES
-- ============================================================================

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

-- ============================================================================
-- API KEYS POLICIES
-- ============================================================================

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

-- ============================================================================
-- AUDIT LOGS POLICIES
-- ============================================================================

CREATE POLICY "Users can view their own audit logs"
  ON sms_gateway.audit_logs
  FOR SELECT
  USING (auth.uid() = user_id);

-- Note: No INSERT/UPDATE/DELETE for audit logs - these are system-generated

-- ============================================================================
-- SETTINGS POLICIES
-- ============================================================================

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

-- ============================================================================
-- COMPLETE
-- ============================================================================
-- These basic policies will be REPLACED by tenant-aware policies
-- when you run add_multi_tenant_support.sql
