-- Public Schema - SaaS Control Plane
-- This schema contains management and control tables for all products
-- Run this BEFORE executing add_multi_tenant_support.sql

-- Products table (catalog of all SaaS products)
CREATE TABLE IF NOT EXISTS public.products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  slug VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  status VARCHAR(50) DEFAULT 'active', -- active, inactive, deprecated
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
  subscription_status VARCHAR(50) DEFAULT 'active', -- active, suspended, cancelled, trial
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
  role VARCHAR(50) DEFAULT 'user', -- admin, manager, user, viewer
  status VARCHAR(50) DEFAULT 'active', -- active, inactive, suspended
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Product Subscriptions table (which clients have access to which products)
CREATE TABLE IF NOT EXISTS public.product_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  subscription_tier VARCHAR(50) DEFAULT 'basic', -- basic, pro, enterprise
  status VARCHAR(50) DEFAULT 'active', -- active, suspended, cancelled, trial
  trial_ends_at TIMESTAMP WITH TIME ZONE,
  billing_cycle_start TIMESTAMP WITH TIME ZONE,
  billing_cycle_end TIMESTAMP WITH TIME ZONE,
  api_quota_limit INTEGER DEFAULT 10000,
  api_quota_used INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(client_id, product_id)
);

-- Client Product Access table (user-level access to products per client)
CREATE TABLE IF NOT EXISTS public.client_product_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.global_users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  product VARCHAR(100) NOT NULL, -- 'sms_gateway', 'inventorymaster', 'smartmenu'
  role VARCHAR(50) DEFAULT 'user', -- admin, manager, user, viewer
  permissions JSONB DEFAULT '{}', -- flexible permissions object
  status VARCHAR(50) DEFAULT 'active', -- active, suspended, inactive
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, client_id, product)
);

-- Product Usage Stats table (track usage per client)
CREATE TABLE IF NOT EXISTS public.product_usage_stats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES public.clients(id) ON DELETE CASCADE,
  product VARCHAR(100) NOT NULL, -- 'sms_gateway', 'inventorymaster', 'smartmenu'
  metric_name VARCHAR(100) NOT NULL, -- 'sms_sent', 'contacts_created', 'api_calls'
  metric_value INTEGER DEFAULT 0,
  stat_date DATE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(client_id, product, metric_name, stat_date)
);

-- Create indexes for better performance
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

-- Enable RLS (Row Level Security)
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.global_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_product_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_usage_stats ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Products table (public read, admin write)
CREATE POLICY "Anyone can view products"
  ON public.products
  FOR SELECT
  USING (status = 'active');

CREATE POLICY "Admins can manage products"
  ON public.products
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins can update products"
  ON public.products
  FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

-- RLS Policies for Clients table
CREATE POLICY "Users can view clients they have access to"
  ON public.clients
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.client_product_access cpa
    WHERE cpa.client_id = id AND cpa.user_id = auth.uid()
  ));

CREATE POLICY "Admins can insert clients"
  ON public.clients
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins can update clients"
  ON public.clients
  FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

-- RLS Policies for Global Users table
CREATE POLICY "Users can view their own profile"
  ON public.global_users
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all users"
  ON public.global_users
  FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Users can update their own profile"
  ON public.global_users
  FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Admins can insert users"
  ON public.global_users
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

-- RLS Policies for Product Subscriptions table
CREATE POLICY "Users can view their client subscriptions"
  ON public.product_subscriptions
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.client_product_access cpa
    WHERE cpa.client_id = client_id AND cpa.user_id = auth.uid()
  ));

CREATE POLICY "Admins can manage subscriptions"
  ON public.product_subscriptions
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins can update subscriptions"
  ON public.product_subscriptions
  FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

-- RLS Policies for Client Product Access table
CREATE POLICY "Users can view their own access records"
  ON public.client_product_access
  FOR SELECT
  USING (auth.uid() = user_id OR EXISTS (
    SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'
  ));

CREATE POLICY "Admins can manage access"
  ON public.client_product_access
  FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

CREATE POLICY "Admins can update access"
  ON public.client_product_access
  FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.global_users WHERE id = auth.uid() AND role = 'admin'));

-- RLS Policies for Product Usage Stats table
CREATE POLICY "Users can view their client usage stats"
  ON public.product_usage_stats
  FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM public.client_product_access cpa
    WHERE cpa.client_id = client_id AND cpa.user_id = auth.uid()
  ));

CREATE POLICY "System can insert usage stats"
  ON public.product_usage_stats
  FOR INSERT
  WITH CHECK (true);

CREATE POLICY "System can update usage stats"
  ON public.product_usage_stats
  FOR UPDATE
  USING (true);

-- Create trigger for updating timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON public.products
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_global_users_updated_at BEFORE UPDATE ON public.global_users
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_product_subscriptions_updated_at BEFORE UPDATE ON public.product_subscriptions
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_client_product_access_updated_at BEFORE UPDATE ON public.client_product_access
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_product_usage_stats_updated_at BEFORE UPDATE ON public.product_usage_stats
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Insert sample data (optional - remove in production)
INSERT INTO public.products (name, slug, description, status) VALUES
  ('SMS Gateway', 'sms-gateway', 'Send bulk SMS messages', 'active'),
  ('Inventory Master', 'inventory-master', 'Manage inventory across locations', 'active'),
  ('SmartMenu', 'smartmenu', 'Digital menu management system', 'active')
ON CONFLICT (slug) DO NOTHING;
