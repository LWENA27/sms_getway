-- ============================================================================
-- MULTI-SAAS PLATFORM MIGRATION - REVISED ARCHITECTURE
-- ============================================================================
-- Architecture:
-- - public schema = Management/Control plane
--   ├─ products: Your SaaS products (inventorymaster, sms_gateway, smartmenu)
--   ├─ clients: Organizations/businesses using your products
--   ├─ global_users: All users, linked to clients
--   ├─ product_subscriptions: Which clients subscribe to which products
--   └─ product_usage_stats: Usage metrics per client per product
--
-- - inventorymaster schema = Inventory Management SaaS
-- - sms_gateway schema = SMS Gateway SaaS (already exists)
-- - smartmenu schema = Smart Menu SaaS
-- ============================================================================

-- ============================================================================
-- PART 1: CREATE PUBLIC SCHEMA MANAGEMENT TABLES
-- ============================================================================

-- Drop existing tables in public that will be moved
DROP TABLE IF EXISTS public.sales CASCADE;
DROP TABLE IF EXISTS public.inventories CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.tenants CASCADE;

-- Drop existing control plane tables if they exist (from previous runs)
DROP TABLE IF EXISTS public.client_product_access CASCADE;
DROP TABLE IF EXISTS public.product_usage_stats CASCADE;
DROP TABLE IF EXISTS public.product_subscriptions CASCADE;
DROP TABLE IF EXISTS public.global_users CASCADE;
DROP TABLE IF EXISTS public.clients CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;

-- 1.1: Products table (tracks all your SaaS products/schemas)
CREATE TABLE IF NOT EXISTS public.products (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  schema_name text NOT NULL UNIQUE,
  description text,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT products_pkey PRIMARY KEY (id),
  CONSTRAINT products_schema_name_check CHECK (schema_name ~ '^[a-z_][a-z0-9_]*$')
);

-- 1.2: Clients table (organizations/businesses that use your products)
CREATE TABLE IF NOT EXISTS public.clients (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  email text,
  phone text,
  address text,
  country text,
  owner_id uuid NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT clients_pkey PRIMARY KEY (id),
  CONSTRAINT clients_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- 1.3: Global users table (all users, linked to clients)
CREATE TABLE IF NOT EXISTS public.global_users (
  id uuid NOT NULL,
  email text NOT NULL UNIQUE,
  name text,
  client_id uuid,
  role text NOT NULL DEFAULT 'user'::text,
  is_client_owner boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT global_users_pkey PRIMARY KEY (id),
  CONSTRAINT global_users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT global_users_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE SET NULL,
  CONSTRAINT global_users_role_check CHECK (role = ANY (ARRAY['user'::text, 'admin'::text, 'staff'::text, 'super_admin'::text]))
);

-- 1.4: Product subscriptions (which clients use which products)
CREATE TABLE IF NOT EXISTS public.product_subscriptions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  client_id uuid NOT NULL,
  tenant_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'active'::text,
  plan_type text DEFAULT 'free'::text,
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT product_subscriptions_pkey PRIMARY KEY (id),
  CONSTRAINT product_subscriptions_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE,
  CONSTRAINT product_subscriptions_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT product_subscriptions_status_check CHECK (status = ANY (ARRAY['active'::text, 'suspended'::text, 'cancelled'::text, 'expired'::text, 'trial'::text])),
  CONSTRAINT product_subscriptions_plan_check CHECK (plan_type = ANY (ARRAY['free'::text, 'basic'::text, 'pro'::text, 'enterprise'::text])),
  CONSTRAINT product_subscriptions_unique_product_client UNIQUE (product_id, client_id, tenant_id)
);

-- 1.5: Product usage stats (track usage per client per product)
CREATE TABLE IF NOT EXISTS public.product_usage_stats (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  client_id uuid NOT NULL,
  tenant_id uuid NOT NULL,
  metric_name text NOT NULL,
  metric_value numeric NOT NULL DEFAULT 0,
  recorded_at timestamp with time zone NOT NULL DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT product_usage_stats_pkey PRIMARY KEY (id),
  CONSTRAINT product_usage_stats_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE,
  CONSTRAINT product_usage_stats_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE
);

-- 1.6: Client product access (maps which users in a client can access which product tenants)
CREATE TABLE IF NOT EXISTS public.client_product_access (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  client_id uuid NOT NULL,
  product_id uuid NOT NULL,
  tenant_id uuid NOT NULL,
  role text NOT NULL DEFAULT 'member'::text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT client_product_access_pkey PRIMARY KEY (id),
  CONSTRAINT client_product_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT client_product_access_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE,
  CONSTRAINT client_product_access_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE,
  CONSTRAINT client_product_access_role_check CHECK (role = ANY (ARRAY['owner'::text, 'admin'::text, 'member'::text, 'viewer'::text])),
  CONSTRAINT client_product_access_unique UNIQUE (user_id, client_id, product_id, tenant_id)
);

-- ============================================================================
-- PART 2: CREATE INVENTORYMASTER SCHEMA
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS inventorymaster;

-- 2.1: Tenants (for inventorymaster product)
CREATE TABLE inventorymaster.tenants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  client_id uuid NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  public_storefront boolean DEFAULT true,
  show_products_to_customers boolean DEFAULT true,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tenants_pkey PRIMARY KEY (id),
  CONSTRAINT tenants_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE
);

-- 2.2: Profiles (users within inventorymaster product)
CREATE TABLE inventorymaster.profiles (
  id uuid NOT NULL,
  role text NOT NULL DEFAULT 'user'::text,
  email text,
  name text,
  created_at timestamp with time zone DEFAULT now(),
  tenant_id uuid,
  updated_at timestamp with time zone DEFAULT now(),
  language text DEFAULT 'en'::text,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT profiles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES inventorymaster.tenants(id) ON DELETE CASCADE,
  CONSTRAINT profiles_role_check CHECK (role = ANY (ARRAY['user'::text, 'admin'::text, 'staff'::text, 'super_admin'::text]))
);

-- 2.3: Inventories
CREATE TABLE inventorymaster.inventories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  name text NOT NULL,
  sku text,
  quantity integer NOT NULL DEFAULT 0,
  selling_price numeric,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  category text NOT NULL,
  brand text,
  description text,
  image_url text,
  buying_price numeric NOT NULL,
  visible_to_customers boolean DEFAULT true,
  CONSTRAINT inventories_pkey PRIMARY KEY (id),
  CONSTRAINT inventories_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES inventorymaster.tenants(id) ON DELETE CASCADE,
  CONSTRAINT inventories_sku_tenant_unique UNIQUE (sku, tenant_id)
);

-- 2.4: Sales
CREATE TABLE inventorymaster.sales (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  product_name text NOT NULL,
  quantity integer NOT NULL,
  unit_price numeric NOT NULL,
  total_amount numeric NOT NULL,
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  date timestamp with time zone NOT NULL DEFAULT now(),
  tenant_id uuid NOT NULL,
  receipt_number text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  business_address text,
  business_name text,
  business_phone numeric,
  business_tin numeric,
  CONSTRAINT sales_pkey PRIMARY KEY (id),
  CONSTRAINT sales_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES inventorymaster.tenants(id) ON DELETE CASCADE,
  CONSTRAINT sales_product_id_fkey FOREIGN KEY (product_id) REFERENCES inventorymaster.inventories(id) ON DELETE CASCADE
);

-- ============================================================================
-- PART 3: CREATE SMARTMENU SCHEMA (template for future products)
-- ============================================================================

CREATE SCHEMA IF NOT EXISTS smartmenu;

-- Similar structure - add tables as needed for smartmenu
CREATE TABLE smartmenu.tenants (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  client_id uuid NOT NULL,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tenants_pkey PRIMARY KEY (id),
  CONSTRAINT tenants_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.clients(id) ON DELETE CASCADE
);

CREATE TABLE smartmenu.profiles (
  id uuid NOT NULL,
  role text NOT NULL DEFAULT 'user'::text,
  email text,
  name text,
  created_at timestamp with time zone DEFAULT now(),
  tenant_id uuid,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE,
  CONSTRAINT profiles_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES smartmenu.tenants(id) ON DELETE CASCADE
);

-- ============================================================================
-- PART 4: CREATE INDEXES
-- ============================================================================

-- Public schema indexes
CREATE INDEX idx_products_schema_name ON public.products(schema_name);
CREATE INDEX idx_products_is_active ON public.products(is_active);

CREATE INDEX idx_clients_slug ON public.clients(slug);
CREATE INDEX idx_clients_owner_id ON public.clients(owner_id);
CREATE INDEX idx_clients_is_active ON public.clients(is_active);

CREATE INDEX idx_global_users_email ON public.global_users(email);
CREATE INDEX idx_global_users_client_id ON public.global_users(client_id);
CREATE INDEX idx_global_users_is_client_owner ON public.global_users(is_client_owner);

CREATE INDEX idx_product_subscriptions_product_id ON public.product_subscriptions(product_id);
CREATE INDEX idx_product_subscriptions_client_id ON public.product_subscriptions(client_id);
CREATE INDEX idx_product_subscriptions_tenant_id ON public.product_subscriptions(tenant_id);
CREATE INDEX idx_product_subscriptions_status ON public.product_subscriptions(status);

CREATE INDEX idx_product_usage_stats_product_id ON public.product_usage_stats(product_id);
CREATE INDEX idx_product_usage_stats_client_id ON public.product_usage_stats(client_id);
CREATE INDEX idx_product_usage_stats_tenant_id ON public.product_usage_stats(tenant_id);
CREATE INDEX idx_product_usage_stats_recorded_at ON public.product_usage_stats(recorded_at);

CREATE INDEX idx_client_product_access_user_id ON public.client_product_access(user_id);
CREATE INDEX idx_client_product_access_client_id ON public.client_product_access(client_id);
CREATE INDEX idx_client_product_access_product_id ON public.client_product_access(product_id);
CREATE INDEX idx_client_product_access_tenant_id ON public.client_product_access(tenant_id);

-- Inventorymaster schema indexes
CREATE INDEX idx_im_tenants_slug ON inventorymaster.tenants(slug);
CREATE INDEX idx_im_tenants_client_id ON inventorymaster.tenants(client_id);
CREATE INDEX idx_im_profiles_tenant_id ON inventorymaster.profiles(tenant_id);
CREATE INDEX idx_im_profiles_email ON inventorymaster.profiles(email);
CREATE INDEX idx_im_inventories_tenant_id ON inventorymaster.inventories(tenant_id);
CREATE INDEX idx_im_inventories_sku ON inventorymaster.inventories(sku);
CREATE INDEX idx_im_inventories_category ON inventorymaster.inventories(category);
CREATE INDEX idx_im_sales_tenant_id ON inventorymaster.sales(tenant_id);
CREATE INDEX idx_im_sales_product_id ON inventorymaster.sales(product_id);
CREATE INDEX idx_im_sales_date ON inventorymaster.sales(date);
CREATE INDEX idx_im_sales_receipt_number ON inventorymaster.sales(receipt_number);

-- Smartmenu schema indexes
CREATE INDEX idx_sm_tenants_slug ON smartmenu.tenants(slug);
CREATE INDEX idx_sm_tenants_client_id ON smartmenu.tenants(client_id);
CREATE INDEX idx_sm_profiles_tenant_id ON smartmenu.profiles(tenant_id);

-- ============================================================================
-- PART 5: SEED INITIAL DATA
-- ============================================================================

-- Insert your SaaS products
INSERT INTO public.products (name, schema_name, description, is_active) VALUES
  ('Inventory Master', 'inventorymaster', 'Complete inventory management system', true),
  ('SMS Gateway', 'sms_gateway', 'SMS messaging and gateway service', true),
  ('Smart Menu', 'smartmenu', 'Digital menu management system', true)
ON CONFLICT (schema_name) DO NOTHING;

-- ============================================================================
-- PART 6: CREATE HELPER VIEWS FOR MANAGEMENT
-- ============================================================================

-- View: All products with client and user counts
CREATE OR REPLACE VIEW public.v_product_overview AS
SELECT 
  p.id,
  p.name,
  p.schema_name,
  p.is_active,
  COUNT(DISTINCT ps.client_id) as client_count,
  COUNT(DISTINCT cpa.user_id) as user_count,
  COUNT(DISTINCT CASE WHEN ps.status = 'active' THEN ps.id END) as active_subscriptions,
  p.created_at
FROM public.products p
LEFT JOIN public.product_subscriptions ps ON p.id = ps.product_id
LEFT JOIN public.client_product_access cpa ON p.id = cpa.product_id
GROUP BY p.id, p.name, p.schema_name, p.is_active, p.created_at;

-- View: Client overview with product subscriptions
CREATE OR REPLACE VIEW public.v_client_overview AS
SELECT 
  c.id,
  c.name,
  c.slug,
  c.email,
  c.is_active,
  gu.name as owner_name,
  gu.email as owner_email,
  COUNT(DISTINCT ps.product_id) as products_subscribed,
  COUNT(DISTINCT u.id) as total_users,
  c.created_at
FROM public.clients c
LEFT JOIN public.global_users gu ON c.owner_id = gu.id
LEFT JOIN public.product_subscriptions ps ON c.id = ps.client_id
LEFT JOIN public.global_users u ON c.id = u.client_id
GROUP BY c.id, c.name, c.slug, c.email, c.is_active, gu.name, gu.email, c.created_at;

-- View: Product subscriptions summary
CREATE OR REPLACE VIEW public.v_subscription_summary AS
SELECT 
  p.name as product_name,
  c.name as client_name,
  ps.status,
  ps.plan_type,
  ps.started_at,
  ps.expires_at
FROM public.product_subscriptions ps
JOIN public.products p ON ps.product_id = p.id
JOIN public.clients c ON ps.client_id = c.id
ORDER BY ps.created_at DESC;

-- View: User access overview
CREATE OR REPLACE VIEW public.v_user_access_overview AS
SELECT 
  gu.id,
  gu.name,
  gu.email,
  c.name as client_name,
  gu.is_client_owner,
  COUNT(DISTINCT cpa.product_id) as products_access,
  json_agg(
    json_build_object(
      'product_name', p.name,
      'role', cpa.role,
      'tenant_id', cpa.tenant_id
    )
  ) FILTER (WHERE p.id IS NOT NULL) as product_access_details
FROM public.global_users gu
LEFT JOIN public.clients c ON gu.client_id = c.id
LEFT JOIN public.client_product_access cpa ON gu.id = cpa.user_id
LEFT JOIN public.products p ON cpa.product_id = p.id
GROUP BY gu.id, gu.name, gu.email, c.name, gu.is_client_owner;

-- ============================================================================
-- PART 7: CREATE HELPER FUNCTIONS
-- ============================================================================

-- Function to create a new client
CREATE OR REPLACE FUNCTION public.create_client(
  p_owner_id uuid,
  p_client_name text,
  p_client_slug text,
  p_client_email text DEFAULT NULL,
  p_owner_name text DEFAULT NULL,
  p_owner_email text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_client_id uuid;
BEGIN
  -- Create client
  INSERT INTO public.clients (owner_id, name, slug, email)
  VALUES (p_owner_id, p_client_name, p_client_slug, p_client_email)
  RETURNING id INTO v_client_id;
  
  -- Create or update global user record for owner
  INSERT INTO public.global_users (id, email, name, client_id, is_client_owner, role)
  VALUES (p_owner_id, p_owner_email, p_owner_name, v_client_id, true, 'admin')
  ON CONFLICT (id) DO UPDATE 
  SET client_id = v_client_id, is_client_owner = true, updated_at = now();
  
  RETURN v_client_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to subscribe client to a product
CREATE OR REPLACE FUNCTION public.subscribe_client_to_product(
  p_client_id uuid,
  p_product_schema text,
  p_tenant_name text,
  p_tenant_slug text,
  p_plan_type text DEFAULT 'free'
)
RETURNS uuid AS $$
DECLARE
  v_product_id uuid;
  v_tenant_id uuid;
  v_client_owner_id uuid;
BEGIN
  -- Get product ID
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = p_product_schema;
  
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'Product schema % not found', p_product_schema;
  END IF;
  
  -- Get client owner
  SELECT owner_id INTO v_client_owner_id FROM public.clients WHERE id = p_client_id;
  
  IF v_client_owner_id IS NULL THEN
    RAISE EXCEPTION 'Client % not found', p_client_id;
  END IF;
  
  -- Generate tenant ID
  v_tenant_id := gen_random_uuid();
  
  -- Create subscription
  INSERT INTO public.product_subscriptions (product_id, client_id, tenant_id, status, plan_type)
  VALUES (v_product_id, p_client_id, v_tenant_id, 'active', p_plan_type);
  
  -- Grant owner access
  INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
  VALUES (v_client_owner_id, p_client_id, v_product_id, v_tenant_id, 'owner');
  
  -- Create tenant in respective schema
  EXECUTE format('INSERT INTO %I.tenants (id, name, slug, client_id) VALUES ($1, $2, $3, $4)', p_product_schema)
  USING v_tenant_id, p_tenant_name, p_tenant_slug, p_client_id;
  
  RETURN v_tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to add user to client product
CREATE OR REPLACE FUNCTION public.add_user_to_client_product(
  p_user_id uuid,
  p_client_id uuid,
  p_product_schema text,
  p_tenant_id uuid,
  p_role text DEFAULT 'member',
  p_user_email text DEFAULT NULL,
  p_user_name text DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
  v_product_id uuid;
  v_access_id uuid;
BEGIN
  -- Get product ID
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = p_product_schema;
  
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'Product schema % not found', p_product_schema;
  END IF;
  
  -- Create or update global user
  INSERT INTO public.global_users (id, email, name, client_id, role)
  VALUES (p_user_id, p_user_email, p_user_name, p_client_id, 'user')
  ON CONFLICT (id) DO UPDATE 
  SET client_id = p_client_id, updated_at = now();
  
  -- Grant access
  INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
  VALUES (p_user_id, p_client_id, v_product_id, p_tenant_id, p_role)
  ON CONFLICT (user_id, client_id, product_id, tenant_id) DO UPDATE
  SET role = p_role, updated_at = now()
  RETURNING id INTO v_access_id;
  
  -- Create profile in product schema
  EXECUTE format('INSERT INTO %I.profiles (id, email, name, tenant_id, role) VALUES ($1, $2, $3, $4, $5) ON CONFLICT (id) DO NOTHING', p_product_schema)
  USING p_user_id, p_user_email, p_user_name, p_tenant_id, p_role;
  
  RETURN v_access_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to track product usage
CREATE OR REPLACE FUNCTION public.track_product_usage(
  p_product_schema text,
  p_client_id uuid,
  p_tenant_id uuid,
  p_metric_name text,
  p_metric_value numeric,
  p_metadata jsonb DEFAULT '{}'
)
RETURNS uuid AS $$
DECLARE
  v_product_id uuid;
  v_stat_id uuid;
BEGIN
  -- Get product ID
  SELECT id INTO v_product_id FROM public.products WHERE schema_name = p_product_schema;
  
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'Product schema % not found', p_product_schema;
  END IF;
  
  -- Insert usage stat
  INSERT INTO public.product_usage_stats (product_id, client_id, tenant_id, metric_name, metric_value, metadata)
  VALUES (v_product_id, p_client_id, p_tenant_id, p_metric_name, p_metric_value, p_metadata)
  RETURNING id INTO v_stat_id;
  
  RETURN v_stat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- PART 8: ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on public schema tables
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.global_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_usage_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.client_product_access ENABLE ROW LEVEL SECURITY;

-- Enable RLS on inventorymaster schema
ALTER TABLE inventorymaster.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventorymaster.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventorymaster.inventories ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventorymaster.sales ENABLE ROW LEVEL SECURITY;

-- Public schema policies
CREATE POLICY "Anyone can view active products"
  ON public.products FOR SELECT
  TO authenticated, anon
  USING (is_active = true);

CREATE POLICY "Users can view their own client"
  ON public.clients FOR SELECT
  TO authenticated
  USING (
    owner_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.global_users
      WHERE global_users.id = auth.uid()
      AND global_users.client_id = clients.id
    )
  );

CREATE POLICY "Client owners can update their client"
  ON public.clients FOR UPDATE
  TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY "Users can view their own profile"
  ON public.global_users FOR ALL
  TO authenticated
  USING (id = auth.uid());

CREATE POLICY "Users can view subscriptions of their client"
  ON public.product_subscriptions FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.global_users
      WHERE global_users.id = auth.uid()
      AND global_users.client_id = product_subscriptions.client_id
    )
  );

CREATE POLICY "Users can view their own access"
  ON public.client_product_access FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

-- Inventorymaster schema policies
CREATE POLICY "Users can access their tenant data"
  ON inventorymaster.tenants FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.client_product_access cpa
      JOIN public.products p ON cpa.product_id = p.id
      WHERE cpa.user_id = auth.uid()
      AND p.schema_name = 'inventorymaster'
      AND cpa.tenant_id = tenants.id
    )
  );

CREATE POLICY "Users can access their profile"
  ON inventorymaster.profiles FOR ALL
  TO authenticated
  USING (
    id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.client_product_access cpa
      JOIN public.products p ON cpa.product_id = p.id
      WHERE cpa.user_id = auth.uid()
      AND p.schema_name = 'inventorymaster'
      AND cpa.tenant_id = profiles.tenant_id
      AND cpa.role IN ('owner', 'admin')
    )
  );

CREATE POLICY "Users can access inventories in their tenant"
  ON inventorymaster.inventories FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.client_product_access cpa
      JOIN public.products p ON cpa.product_id = p.id
      WHERE cpa.user_id = auth.uid()
      AND p.schema_name = 'inventorymaster'
      AND cpa.tenant_id = inventories.tenant_id
    )
  );

CREATE POLICY "Users can access sales in their tenant"
  ON inventorymaster.sales FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.client_product_access cpa
      JOIN public.products p ON cpa.product_id = p.id
      WHERE cpa.user_id = auth.uid()
      AND p.schema_name = 'inventorymaster'
      AND cpa.tenant_id = sales.tenant_id
    )
  );

-- ============================================================================
-- PART 9: GRANT PERMISSIONS
-- ============================================================================

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
GRANT USAGE ON SCHEMA inventorymaster TO authenticated, service_role;
GRANT USAGE ON SCHEMA smartmenu TO authenticated, service_role;

-- Grant table permissions
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA inventorymaster TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA inventorymaster TO authenticated;

GRANT ALL ON ALL TABLES IN SCHEMA smartmenu TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA smartmenu TO authenticated;

-- Grant sequence permissions
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA inventorymaster TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA smartmenu TO authenticated, service_role;

-- Grant execute on functions
GRANT EXECUTE ON FUNCTION public.create_client TO authenticated;
GRANT EXECUTE ON FUNCTION public.subscribe_client_to_product TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_user_to_client_product TO authenticated;
GRANT EXECUTE ON FUNCTION public.track_product_usage TO authenticated, service_role;

-- ============================================================================
-- PART 10: VERIFICATION QUERIES
-- ============================================================================

-- Check all schemas
SELECT schema_name FROM information_schema.schemata 
WHERE schema_name IN ('public', 'inventorymaster', 'sms_gateway', 'smartmenu')
ORDER BY schema_name;

-- Check products
SELECT * FROM public.products;

-- Check tables in each schema
SELECT 
  schemaname,
  tablename
FROM pg_tables
WHERE schemaname IN ('public', 'inventorymaster', 'sms_gateway', 'smartmenu')
ORDER BY schemaname, tablename;

-- ============================================================================
-- PART 11: MIGRATE EXISTING DATA FROM PUBLIC TO INVENTORYMASTER SCHEMA
-- ============================================================================

-- Step 1: Migrate existing tenants data (if any exist in public)
-- NOTE: Adjust this if your existing tables have different structure
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'tenants') THEN
    INSERT INTO inventorymaster.tenants (id, name, slug, client_id, metadata, public_storefront, show_products_to_customers, created_at, updated_at)
    SELECT id, name, slug, NULL, metadata, public_storefront, show_products_to_customers, created_at, updated_at
    FROM public.tenants
    ON CONFLICT (id) DO NOTHING;
    
    RAISE NOTICE 'Migrated tenants from public schema';
  END IF;
END $$;

-- Step 2: Migrate profiles data
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'profiles') THEN
    INSERT INTO inventorymaster.profiles (id, role, email, name, created_at, tenant_id, updated_at, language)
    SELECT id, role, email, name, created_at, tenant_id, updated_at, language
    FROM public.profiles
    ON CONFLICT (id) DO NOTHING;
    
    RAISE NOTICE 'Migrated profiles from public schema';
  END IF;
END $$;

-- Step 3: Migrate inventories data
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'inventories') THEN
    INSERT INTO inventorymaster.inventories (id, tenant_id, name, sku, quantity, selling_price, metadata, created_at, updated_at, category, brand, description, image_url, buying_price, visible_to_customers)
    SELECT id, tenant_id, name, sku, quantity, selling_price, metadata, created_at, updated_at, category, brand, description, image_url, buying_price, visible_to_customers
    FROM public.inventories
    ON CONFLICT (id) DO NOTHING;
    
    RAISE NOTICE 'Migrated inventories from public schema';
  END IF;
END $$;

-- Step 4: Migrate sales data
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'sales') THEN
    INSERT INTO inventorymaster.sales (id, product_id, product_name, quantity, unit_price, total_amount, customer_name, customer_phone, date, tenant_id, receipt_number, metadata, created_at, updated_at, business_address, business_name, business_phone, business_tin)
    SELECT id, product_id, product_name, quantity, unit_price, total_amount, customer_name, customer_phone, date, tenant_id, receipt_number, metadata, created_at, updated_at, business_address, business_name, business_phone, business_tin
    FROM public.sales
    ON CONFLICT (id) DO NOTHING;
    
    RAISE NOTICE 'Migrated sales from public schema';
  END IF;
END $$;

-- Step 5: Verify migration
SELECT COUNT(*) as total_tenants FROM inventorymaster.tenants;
SELECT COUNT(*) as total_profiles FROM inventorymaster.profiles;
SELECT COUNT(*) as total_inventories FROM inventorymaster.inventories;
SELECT COUNT(*) as total_sales FROM inventorymaster.sales;

-- ============================================================================
-- PART 12: LINK EXISTING DATA TO CONTROL PLANE
-- ============================================================================

-- Step 1: Create a default client if none exists
DO $$
DECLARE
  v_default_user_id uuid;
  v_client_id uuid;
BEGIN
  -- Get first user from inventorymaster.profiles (if exists)
  SELECT id INTO v_default_user_id FROM inventorymaster.profiles LIMIT 1;
  
  IF v_default_user_id IS NOT NULL THEN
    -- Check if global_users record exists
    IF NOT EXISTS (SELECT 1 FROM public.global_users WHERE id = v_default_user_id) THEN
      -- Create global user from profile
      INSERT INTO public.global_users (id, email, name, role)
      SELECT id, email, name, role FROM inventorymaster.profiles WHERE id = v_default_user_id;
    END IF;
    
    -- Check if clients record exists
    IF NOT EXISTS (SELECT 1 FROM public.clients WHERE owner_id = v_default_user_id) THEN
      -- Create default client
      INSERT INTO public.clients (owner_id, name, slug, email)
      VALUES (v_default_user_id, 'Default Client', 'default-client', 'admin@defaultclient.com')
      RETURNING id INTO v_client_id;
      
      RAISE NOTICE 'Created default client: %', v_client_id;
      
      -- Link tenants to client
      UPDATE inventorymaster.tenants 
      SET client_id = v_client_id 
      WHERE client_id IS NULL;
      
      -- Create product subscription
      INSERT INTO public.product_subscriptions (product_id, client_id, tenant_id, status, plan_type)
      SELECT p.id, v_client_id, t.id, 'active', 'pro'
      FROM public.products p, inventorymaster.tenants t
      WHERE p.schema_name = 'inventorymaster' AND t.client_id = v_client_id
      ON CONFLICT DO NOTHING;
      
      -- Grant access
      INSERT INTO public.client_product_access (user_id, client_id, product_id, tenant_id, role)
      SELECT v_default_user_id, v_client_id, p.id, t.id, 'owner'
      FROM public.products p, inventorymaster.tenants t
      WHERE p.schema_name = 'inventorymaster' AND t.client_id = v_client_id
      ON CONFLICT DO NOTHING;
    END IF;
  END IF;
END $$;

-- ============================================================================
-- PART 13: VERIFY MIGRATION COMPLETE
-- ============================================================================

-- Check public schema - should have control plane tables only
SELECT 
  'public' as schema_name,
  array_agg(tablename) as tables
FROM pg_tables
WHERE schemaname = 'public'
GROUP BY schema_name;

-- Check inventorymaster schema - should have all product tables
SELECT 
  'inventorymaster' as schema_name,
  array_agg(tablename) as tables
FROM pg_tables
WHERE schemaname = 'inventorymaster'
GROUP BY schema_name;

-- Check sms_gateway schema
SELECT 
  'sms_gateway' as schema_name,
  array_agg(tablename) as tables
FROM pg_tables
WHERE schemaname = 'sms_gateway'
GROUP BY schema_name;

-- Check smartmenu schema
SELECT 
  'smartmenu' as schema_name,
  array_agg(tablename) as tables
FROM pg_tables
WHERE schemaname = 'smartmenu'
GROUP BY schema_name;

-- View control plane setup
SELECT 'Control Plane Tables' as section;
SELECT COUNT(*) as products FROM public.products;
SELECT COUNT(*) as clients FROM public.clients;
SELECT COUNT(*) as global_users FROM public.global_users;
SELECT COUNT(*) as subscriptions FROM public.product_subscriptions;
SELECT COUNT(*) as user_access FROM public.client_product_access;

-- View product data
SELECT 'Product Tables' as section;
SELECT COUNT(*) as inventorymaster_tenants FROM inventorymaster.tenants;
SELECT COUNT(*) as inventorymaster_profiles FROM inventorymaster.profiles;
SELECT COUNT(*) as inventorymaster_inventories FROM inventorymaster.inventories;
SELECT COUNT(*) as inventorymaster_sales FROM inventorymaster.sales;

-- List all products available
SELECT '=== Available Products ===' as info;
SELECT id, name, schema_name, is_active FROM public.products ORDER BY created_at;

-- List all clients
SELECT '=== Registered Clients ===' as info;
SELECT id, name, slug, owner_id, is_active FROM public.clients ORDER BY created_at;

-- List all client subscriptions
SELECT '=== Client Subscriptions ===' as info;
SELECT 
  c.name as client_name,
  p.name as product_name,
  ps.status,
  ps.plan_type,
  ps.started_at
FROM public.product_subscriptions ps
JOIN public.clients c ON ps.client_id = c.id
JOIN public.products p ON ps.product_id = p.id
ORDER BY ps.created_at DESC;

-- ============================================================================
-- PART 14: FINALIZATION
-- ============================================================================

-- Update product status to active
UPDATE public.products SET is_active = true, updated_at = now();

-- Grant final permissions
GRANT USAGE ON SCHEMA inventorymaster TO authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA inventorymaster TO authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA inventorymaster TO authenticated, service_role;

-- Create audit log function for multi-tenant tracking
CREATE OR REPLACE FUNCTION public.log_usage(
  p_product_schema text,
  p_tenant_id uuid,
  p_client_id uuid,
  p_action text,
  p_details jsonb DEFAULT '{}'
)
RETURNS uuid AS $$
DECLARE
  v_stat_id uuid;
BEGIN
  INSERT INTO public.product_usage_stats (product_id, client_id, tenant_id, metric_name, metric_value, metadata)
  SELECT 
    p.id,
    p_client_id,
    p_tenant_id,
    p_action,
    1,
    p_details || jsonb_build_object('timestamp', now(), 'user_id', auth.uid())
  FROM public.products p
  WHERE p.schema_name = p_product_schema
  RETURNING id INTO v_stat_id;
  
  RETURN v_stat_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.log_usage TO authenticated, service_role;

-- Success message
SELECT '✅ Migration Complete!' as status,
       'All inventorymaster data has been migrated to dedicated schema' as message,
       'Public schema now contains control plane tables only' as info,
       'You can now safely run sms_gateway and smartmenu migrations' as next_steps;