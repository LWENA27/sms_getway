

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "inventorymaster";


ALTER SCHEMA "inventorymaster" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE SCHEMA IF NOT EXISTS "smartmenu";


ALTER SCHEMA "smartmenu" OWNER TO "postgres";


CREATE SCHEMA IF NOT EXISTS "sms_gateway";


ALTER SCHEMA "sms_gateway" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."add_user_to_client_product"("p_user_id" "uuid", "p_client_id" "uuid", "p_product_schema" "text", "p_tenant_id" "uuid", "p_role" "text" DEFAULT 'member'::"text", "p_user_email" "text" DEFAULT NULL::"text", "p_user_name" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
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
$_$;


ALTER FUNCTION "public"."add_user_to_client_product"("p_user_id" "uuid", "p_client_id" "uuid", "p_product_schema" "text", "p_tenant_id" "uuid", "p_role" "text", "p_user_email" "text", "p_user_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_client"("p_owner_id" "uuid", "p_client_name" "text", "p_client_slug" "text", "p_client_email" "text" DEFAULT NULL::"text", "p_owner_name" "text" DEFAULT NULL::"text", "p_owner_email" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."create_client"("p_owner_id" "uuid", "p_client_name" "text", "p_client_slug" "text", "p_client_email" "text", "p_owner_name" "text", "p_owner_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_user_type"("user_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN (
        SELECT raw_user_meta_data->>'user_type'
        FROM auth.users
        WHERE id = user_id
    );
END;
$$;


ALTER FUNCTION "public"."get_user_type"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    INSERT INTO public.profiles (id, email, role)
    VALUES (new.id, new.email, 'admin')
    ON CONFLICT (id) DO NOTHING;
    RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_user_type"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    user_type text;
BEGIN
    -- Get the user type based on existing records
    SELECT
        CASE
            WHEN EXISTS (SELECT 1 FROM public.farmers WHERE user_id = NEW.id) THEN 'farmer'
            WHEN EXISTS (SELECT 1 FROM public.vets WHERE user_id = NEW.id) THEN 'vet'
            ELSE COALESCE(NEW.raw_user_meta_data->>'user_type', 'unassigned')
        END INTO user_type;

    -- Update user metadata with user_type
    NEW.raw_user_meta_data =
        COALESCE(NEW.raw_user_meta_data, '{}'::jsonb) ||
        jsonb_build_object('user_type', user_type);

    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."handle_user_type"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_super_admin"("user_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = user_id AND role = 'super_admin'
    );
END;
$$;


ALTER FUNCTION "public"."is_super_admin"("user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_usage"("p_product_schema" "text", "p_tenant_id" "uuid", "p_client_id" "uuid", "p_action" "text", "p_details" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."log_usage"("p_product_schema" "text", "p_tenant_id" "uuid", "p_client_id" "uuid", "p_action" "text", "p_details" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."promote_to_super_admin"("user_email" "text") RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    user_id UUID;
BEGIN
    -- Find user by email
    SELECT auth.users.id INTO user_id
    FROM auth.users
    WHERE auth.users.email = user_email;
    
    IF user_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Update or insert profile with super_admin role
    INSERT INTO profiles (id, role, updated_at)
    VALUES (user_id, 'super_admin', NOW())
    ON CONFLICT (id) 
    DO UPDATE SET 
        role = 'super_admin',
        updated_at = NOW();
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."promote_to_super_admin"("user_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."setup_test_admin"("user_email" "text", "user_id" "uuid" DEFAULT NULL::"uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    found_user_id UUID;
    test_tenant_id UUID := '11111111-1111-1111-1111-111111111111';
BEGIN
    -- Find user by email if ID not provided
    IF user_id IS NULL THEN
        SELECT id INTO found_user_id
        FROM auth.users
        WHERE email = user_email
        LIMIT 1;
        
        IF found_user_id IS NULL THEN
            RETURN 'Error: User with email ' || user_email || ' not found';
        END IF;
    ELSE
        found_user_id := user_id;
    END IF;
    
    -- Update or insert profile
    INSERT INTO public.profiles (id, email, role, tenant_id, created_at, updated_at)
    VALUES (found_user_id, user_email, 'admin', test_tenant_id, NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        role = 'admin',
        tenant_id = test_tenant_id,
        updated_at = NOW();
    
    RETURN 'Success: User ' || user_email || ' is now admin of Test Store';
END;
$$;


ALTER FUNCTION "public"."setup_test_admin"("user_email" "text", "user_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."subscribe_client_to_product"("p_client_id" "uuid", "p_product_schema" "text", "p_tenant_name" "text", "p_tenant_slug" "text", "p_plan_type" "text" DEFAULT 'free'::"text") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $_$
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
$_$;


ALTER FUNCTION "public"."subscribe_client_to_product"("p_client_id" "uuid", "p_product_schema" "text", "p_tenant_name" "text", "p_tenant_slug" "text", "p_plan_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."track_product_usage"("p_product_schema" "text", "p_client_id" "uuid", "p_tenant_id" "uuid", "p_metric_name" "text", "p_metric_value" numeric, "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."track_product_usage"("p_product_schema" "text", "p_client_id" "uuid", "p_tenant_id" "uuid", "p_metric_name" "text", "p_metric_value" numeric, "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_set_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_set_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_user_type"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    IF TG_TABLE_NAME = 'farmers' THEN
        UPDATE auth.users
        SET raw_user_meta_data =
            COALESCE(raw_user_meta_data, '{}'::jsonb) ||
            jsonb_build_object('user_type', 'farmer')
        WHERE id = NEW.user_id;
    ELSIF TG_TABLE_NAME = 'vets' THEN
        UPDATE auth.users
        SET raw_user_meta_data =
            COALESCE(raw_user_meta_data, '{}'::jsonb) ||
            jsonb_build_object('user_type', 'vet')
        WHERE id = NEW.user_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_user_type"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "sms_gateway"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "sms_gateway"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "inventorymaster"."inventories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "sku" "text",
    "quantity" integer DEFAULT 0 NOT NULL,
    "selling_price" numeric,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "category" "text" NOT NULL,
    "brand" "text",
    "description" "text",
    "image_url" "text",
    "buying_price" numeric NOT NULL,
    "visible_to_customers" boolean DEFAULT true
);


ALTER TABLE "inventorymaster"."inventories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "inventorymaster"."profiles" (
    "id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'user'::"text" NOT NULL,
    "email" "text",
    "name" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "tenant_id" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "language" "text" DEFAULT 'en'::"text",
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['user'::"text", 'admin'::"text", 'staff'::"text", 'super_admin'::"text"])))
);


ALTER TABLE "inventorymaster"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "inventorymaster"."sales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "product_name" "text" NOT NULL,
    "quantity" integer NOT NULL,
    "unit_price" numeric NOT NULL,
    "total_amount" numeric NOT NULL,
    "customer_name" "text" NOT NULL,
    "customer_phone" "text" NOT NULL,
    "date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "receipt_number" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "business_address" "text",
    "business_name" "text",
    "business_phone" numeric,
    "business_tin" numeric
);


ALTER TABLE "inventorymaster"."sales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "inventorymaster"."tenants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "public_storefront" boolean DEFAULT true,
    "show_products_to_customers" boolean DEFAULT true,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "inventorymaster"."tenants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."client_product_access" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'member'::"text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "client_product_access_role_check" CHECK (("role" = ANY (ARRAY['owner'::"text", 'admin'::"text", 'member'::"text", 'viewer'::"text"])))
);


ALTER TABLE "public"."client_product_access" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clients" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "email" "text",
    "phone" "text",
    "address" "text",
    "country" "text",
    "owner_id" "uuid" NOT NULL,
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."clients" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."global_users" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "name" "text",
    "client_id" "uuid",
    "role" "text" DEFAULT 'user'::"text" NOT NULL,
    "is_client_owner" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    CONSTRAINT "global_users_role_check" CHECK (("role" = ANY (ARRAY['user'::"text", 'admin'::"text", 'staff'::"text", 'super_admin'::"text"])))
);


ALTER TABLE "public"."global_users" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_subscriptions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "plan_type" "text" DEFAULT 'free'::"text",
    "started_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "expires_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    CONSTRAINT "product_subscriptions_plan_check" CHECK (("plan_type" = ANY (ARRAY['free'::"text", 'basic'::"text", 'pro'::"text", 'enterprise'::"text"]))),
    CONSTRAINT "product_subscriptions_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'suspended'::"text", 'cancelled'::"text", 'expired'::"text", 'trial'::"text"])))
);


ALTER TABLE "public"."product_subscriptions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."product_usage_stats" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "product_id" "uuid" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "metric_name" "text" NOT NULL,
    "metric_value" numeric DEFAULT 0 NOT NULL,
    "recorded_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."product_usage_stats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "schema_name" "text" NOT NULL,
    "description" "text",
    "is_active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    CONSTRAINT "products_schema_name_check" CHECK (("schema_name" ~ '^[a-z_][a-z0-9_]*$'::"text"))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_client_overview" AS
 SELECT "c"."id",
    "c"."name",
    "c"."slug",
    "c"."email",
    "c"."is_active",
    "gu"."name" AS "owner_name",
    "gu"."email" AS "owner_email",
    "count"(DISTINCT "ps"."product_id") AS "products_subscribed",
    "count"(DISTINCT "u"."id") AS "total_users",
    "c"."created_at"
   FROM ((("public"."clients" "c"
     LEFT JOIN "public"."global_users" "gu" ON (("c"."owner_id" = "gu"."id")))
     LEFT JOIN "public"."product_subscriptions" "ps" ON (("c"."id" = "ps"."client_id")))
     LEFT JOIN "public"."global_users" "u" ON (("c"."id" = "u"."client_id")))
  GROUP BY "c"."id", "c"."name", "c"."slug", "c"."email", "c"."is_active", "gu"."name", "gu"."email", "c"."created_at";


ALTER TABLE "public"."v_client_overview" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_product_overview" AS
 SELECT "p"."id",
    "p"."name",
    "p"."schema_name",
    "p"."is_active",
    "count"(DISTINCT "ps"."client_id") AS "client_count",
    "count"(DISTINCT "cpa"."user_id") AS "user_count",
    "count"(DISTINCT
        CASE
            WHEN ("ps"."status" = 'active'::"text") THEN "ps"."id"
            ELSE NULL::"uuid"
        END) AS "active_subscriptions",
    "p"."created_at"
   FROM (("public"."products" "p"
     LEFT JOIN "public"."product_subscriptions" "ps" ON (("p"."id" = "ps"."product_id")))
     LEFT JOIN "public"."client_product_access" "cpa" ON (("p"."id" = "cpa"."product_id")))
  GROUP BY "p"."id", "p"."name", "p"."schema_name", "p"."is_active", "p"."created_at";


ALTER TABLE "public"."v_product_overview" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_subscription_summary" AS
 SELECT "p"."name" AS "product_name",
    "c"."name" AS "client_name",
    "ps"."status",
    "ps"."plan_type",
    "ps"."started_at",
    "ps"."expires_at"
   FROM (("public"."product_subscriptions" "ps"
     JOIN "public"."products" "p" ON (("ps"."product_id" = "p"."id")))
     JOIN "public"."clients" "c" ON (("ps"."client_id" = "c"."id")))
  ORDER BY "ps"."created_at" DESC;


ALTER TABLE "public"."v_subscription_summary" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_user_access_overview" AS
 SELECT "gu"."id",
    "gu"."name",
    "gu"."email",
    "c"."name" AS "client_name",
    "gu"."is_client_owner",
    "count"(DISTINCT "cpa"."product_id") AS "products_access",
    "json_agg"("json_build_object"('product_name', "p"."name", 'role', "cpa"."role", 'tenant_id', "cpa"."tenant_id")) FILTER (WHERE ("p"."id" IS NOT NULL)) AS "product_access_details"
   FROM ((("public"."global_users" "gu"
     LEFT JOIN "public"."clients" "c" ON (("gu"."client_id" = "c"."id")))
     LEFT JOIN "public"."client_product_access" "cpa" ON (("gu"."id" = "cpa"."user_id")))
     LEFT JOIN "public"."products" "p" ON (("cpa"."product_id" = "p"."id")))
  GROUP BY "gu"."id", "gu"."name", "gu"."email", "c"."name", "gu"."is_client_owner";


ALTER TABLE "public"."v_user_access_overview" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "smartmenu"."profiles" (
    "id" "uuid" NOT NULL,
    "role" "text" DEFAULT 'user'::"text" NOT NULL,
    "email" "text",
    "name" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "tenant_id" "uuid",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "smartmenu"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "smartmenu"."tenants" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "client_id" "uuid" NOT NULL,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "smartmenu"."tenants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "sms_gateway"."api_keys" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" character varying(255) NOT NULL,
    "key_hash" character varying(255) NOT NULL,
    "last_used" timestamp with time zone,
    "active" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tenant_id" "uuid" NOT NULL
);


ALTER TABLE "sms_gateway"."api_keys" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "sms_gateway"."audit_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "action" character varying(100) NOT NULL,
    "table_name" character varying(100),
    "record_id" "uuid",
    "old_values" "jsonb",
    "new_values" "jsonb",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tenant_id" "uuid" NOT NULL
);


ALTER TABLE "sms_gateway"."audit_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "sms_gateway"."contacts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" character varying(255) NOT NULL,
    "phone_number" character varying(20) NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tenant_id" "uuid" NOT NULL
);


ALTER TABLE "sms_gateway"."contacts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "sms_gateway"."group_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid" NOT NULL,
    "contact_id" "uuid" NOT NULL,
    "added_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tenant_id" "uuid" NOT NULL
);


ALTER TABLE "sms_gateway"."group_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "sms_gateway"."groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" character varying(255) NOT NULL,
    "description" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tenant_id" "uuid" NOT NULL
);


ALTER TABLE "sms_gateway"."groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "sms_gateway"."settings" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "setting_key" character varying(255) NOT NULL,
    "setting_value" "jsonb",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tenant_id" "uuid" NOT NULL
);


ALTER TABLE "sms_gateway"."settings" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "sms_gateway"."sms_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "contact_id" "uuid",
    "phone_number" character varying(20) NOT NULL,
    "message" "text" NOT NULL,
    "status" character varying(50) DEFAULT 'pending'::character varying,
    "sent_at" timestamp with time zone,
    "error_message" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tenant_id" "uuid" NOT NULL
);


ALTER TABLE "sms_gateway"."sms_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "sms_gateway"."users" (
    "id" "uuid" NOT NULL,
    "email" character varying(255) NOT NULL,
    "name" character varying(255),
    "phone_number" character varying(20),
    "role" character varying(50) DEFAULT 'user'::character varying,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "tenant_id" "uuid"
);


ALTER TABLE "sms_gateway"."users" OWNER TO "postgres";


ALTER TABLE ONLY "inventorymaster"."inventories"
    ADD CONSTRAINT "inventories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "inventorymaster"."inventories"
    ADD CONSTRAINT "inventories_sku_tenant_unique" UNIQUE ("sku", "tenant_id");



ALTER TABLE ONLY "inventorymaster"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "inventorymaster"."sales"
    ADD CONSTRAINT "sales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "inventorymaster"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "inventorymaster"."tenants"
    ADD CONSTRAINT "tenants_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."client_product_access"
    ADD CONSTRAINT "client_product_access_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."client_product_access"
    ADD CONSTRAINT "client_product_access_unique" UNIQUE ("user_id", "client_id", "product_id", "tenant_id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "public"."global_users"
    ADD CONSTRAINT "global_users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."global_users"
    ADD CONSTRAINT "global_users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_subscriptions"
    ADD CONSTRAINT "product_subscriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_subscriptions"
    ADD CONSTRAINT "product_subscriptions_unique_product_client" UNIQUE ("product_id", "client_id", "tenant_id");



ALTER TABLE ONLY "public"."product_usage_stats"
    ADD CONSTRAINT "product_usage_stats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_schema_name_key" UNIQUE ("schema_name");



ALTER TABLE ONLY "smartmenu"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "smartmenu"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "smartmenu"."tenants"
    ADD CONSTRAINT "tenants_slug_key" UNIQUE ("slug");



ALTER TABLE ONLY "sms_gateway"."api_keys"
    ADD CONSTRAINT "api_keys_key_hash_key" UNIQUE ("key_hash");



ALTER TABLE ONLY "sms_gateway"."api_keys"
    ADD CONSTRAINT "api_keys_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "sms_gateway"."audit_logs"
    ADD CONSTRAINT "audit_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "sms_gateway"."contacts"
    ADD CONSTRAINT "contacts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "sms_gateway"."group_members"
    ADD CONSTRAINT "group_members_group_id_contact_id_key" UNIQUE ("group_id", "contact_id");



ALTER TABLE ONLY "sms_gateway"."group_members"
    ADD CONSTRAINT "group_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "sms_gateway"."groups"
    ADD CONSTRAINT "groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "sms_gateway"."settings"
    ADD CONSTRAINT "settings_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "sms_gateway"."settings"
    ADD CONSTRAINT "settings_user_id_setting_key_key" UNIQUE ("user_id", "setting_key");



ALTER TABLE ONLY "sms_gateway"."sms_logs"
    ADD CONSTRAINT "sms_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "sms_gateway"."users"
    ADD CONSTRAINT "users_email_key" UNIQUE ("email");



ALTER TABLE ONLY "sms_gateway"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_im_inventories_category" ON "inventorymaster"."inventories" USING "btree" ("category");



CREATE INDEX "idx_im_inventories_sku" ON "inventorymaster"."inventories" USING "btree" ("sku");



CREATE INDEX "idx_im_inventories_tenant_id" ON "inventorymaster"."inventories" USING "btree" ("tenant_id");



CREATE INDEX "idx_im_profiles_email" ON "inventorymaster"."profiles" USING "btree" ("email");



CREATE INDEX "idx_im_profiles_tenant_id" ON "inventorymaster"."profiles" USING "btree" ("tenant_id");



CREATE INDEX "idx_im_sales_date" ON "inventorymaster"."sales" USING "btree" ("date");



CREATE INDEX "idx_im_sales_product_id" ON "inventorymaster"."sales" USING "btree" ("product_id");



CREATE INDEX "idx_im_sales_receipt_number" ON "inventorymaster"."sales" USING "btree" ("receipt_number");



CREATE INDEX "idx_im_sales_tenant_id" ON "inventorymaster"."sales" USING "btree" ("tenant_id");



CREATE INDEX "idx_im_tenants_client_id" ON "inventorymaster"."tenants" USING "btree" ("client_id");



CREATE INDEX "idx_im_tenants_slug" ON "inventorymaster"."tenants" USING "btree" ("slug");



CREATE INDEX "idx_client_product_access_client_id" ON "public"."client_product_access" USING "btree" ("client_id");



CREATE INDEX "idx_client_product_access_product_id" ON "public"."client_product_access" USING "btree" ("product_id");



CREATE INDEX "idx_client_product_access_tenant_id" ON "public"."client_product_access" USING "btree" ("tenant_id");



CREATE INDEX "idx_client_product_access_user_id" ON "public"."client_product_access" USING "btree" ("user_id");



CREATE INDEX "idx_clients_is_active" ON "public"."clients" USING "btree" ("is_active");



CREATE INDEX "idx_clients_owner_id" ON "public"."clients" USING "btree" ("owner_id");



CREATE INDEX "idx_clients_slug" ON "public"."clients" USING "btree" ("slug");



CREATE INDEX "idx_global_users_client_id" ON "public"."global_users" USING "btree" ("client_id");



CREATE INDEX "idx_global_users_email" ON "public"."global_users" USING "btree" ("email");



CREATE INDEX "idx_global_users_is_client_owner" ON "public"."global_users" USING "btree" ("is_client_owner");



CREATE INDEX "idx_product_subscriptions_client_id" ON "public"."product_subscriptions" USING "btree" ("client_id");



CREATE INDEX "idx_product_subscriptions_product_id" ON "public"."product_subscriptions" USING "btree" ("product_id");



CREATE INDEX "idx_product_subscriptions_status" ON "public"."product_subscriptions" USING "btree" ("status");



CREATE INDEX "idx_product_subscriptions_tenant_id" ON "public"."product_subscriptions" USING "btree" ("tenant_id");



CREATE INDEX "idx_product_usage_stats_client_id" ON "public"."product_usage_stats" USING "btree" ("client_id");



CREATE INDEX "idx_product_usage_stats_product_id" ON "public"."product_usage_stats" USING "btree" ("product_id");



CREATE INDEX "idx_product_usage_stats_recorded_at" ON "public"."product_usage_stats" USING "btree" ("recorded_at");



CREATE INDEX "idx_product_usage_stats_tenant_id" ON "public"."product_usage_stats" USING "btree" ("tenant_id");



CREATE INDEX "idx_products_is_active" ON "public"."products" USING "btree" ("is_active");



CREATE INDEX "idx_products_schema_name" ON "public"."products" USING "btree" ("schema_name");



CREATE INDEX "idx_sm_profiles_tenant_id" ON "smartmenu"."profiles" USING "btree" ("tenant_id");



CREATE INDEX "idx_sm_tenants_client_id" ON "smartmenu"."tenants" USING "btree" ("client_id");



CREATE INDEX "idx_sm_tenants_slug" ON "smartmenu"."tenants" USING "btree" ("slug");



CREATE INDEX "idx_sms_gateway_api_keys_tenant_id" ON "sms_gateway"."api_keys" USING "btree" ("tenant_id");



CREATE INDEX "idx_sms_gateway_api_keys_user_id" ON "sms_gateway"."api_keys" USING "btree" ("user_id");



CREATE INDEX "idx_sms_gateway_audit_logs_tenant_id" ON "sms_gateway"."audit_logs" USING "btree" ("tenant_id");



CREATE INDEX "idx_sms_gateway_audit_logs_user_id" ON "sms_gateway"."audit_logs" USING "btree" ("user_id");



CREATE INDEX "idx_sms_gateway_contacts_tenant_id" ON "sms_gateway"."contacts" USING "btree" ("tenant_id");



CREATE INDEX "idx_sms_gateway_contacts_user_id" ON "sms_gateway"."contacts" USING "btree" ("user_id");



CREATE INDEX "idx_sms_gateway_contacts_user_tenant" ON "sms_gateway"."contacts" USING "btree" ("user_id", "tenant_id");



CREATE INDEX "idx_sms_gateway_group_members_contact_id" ON "sms_gateway"."group_members" USING "btree" ("contact_id");



CREATE INDEX "idx_sms_gateway_group_members_group_id" ON "sms_gateway"."group_members" USING "btree" ("group_id");



CREATE INDEX "idx_sms_gateway_group_members_tenant_id" ON "sms_gateway"."group_members" USING "btree" ("tenant_id");



CREATE INDEX "idx_sms_gateway_groups_tenant_id" ON "sms_gateway"."groups" USING "btree" ("tenant_id");



CREATE INDEX "idx_sms_gateway_groups_user_id" ON "sms_gateway"."groups" USING "btree" ("user_id");



CREATE INDEX "idx_sms_gateway_groups_user_tenant" ON "sms_gateway"."groups" USING "btree" ("user_id", "tenant_id");



CREATE INDEX "idx_sms_gateway_settings_tenant_id" ON "sms_gateway"."settings" USING "btree" ("tenant_id");



CREATE INDEX "idx_sms_gateway_settings_user_id" ON "sms_gateway"."settings" USING "btree" ("user_id");



CREATE INDEX "idx_sms_gateway_sms_logs_created_at" ON "sms_gateway"."sms_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_sms_gateway_sms_logs_status" ON "sms_gateway"."sms_logs" USING "btree" ("status");



CREATE INDEX "idx_sms_gateway_sms_logs_tenant_id" ON "sms_gateway"."sms_logs" USING "btree" ("tenant_id");



CREATE INDEX "idx_sms_gateway_sms_logs_user_id" ON "sms_gateway"."sms_logs" USING "btree" ("user_id");



CREATE INDEX "idx_sms_gateway_sms_logs_user_tenant" ON "sms_gateway"."sms_logs" USING "btree" ("user_id", "tenant_id");



CREATE INDEX "idx_sms_gateway_users_tenant_id" ON "sms_gateway"."users" USING "btree" ("tenant_id");



CREATE OR REPLACE TRIGGER "update_api_keys_updated_at" BEFORE UPDATE ON "sms_gateway"."api_keys" FOR EACH ROW EXECUTE FUNCTION "sms_gateway"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_contacts_updated_at" BEFORE UPDATE ON "sms_gateway"."contacts" FOR EACH ROW EXECUTE FUNCTION "sms_gateway"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_groups_updated_at" BEFORE UPDATE ON "sms_gateway"."groups" FOR EACH ROW EXECUTE FUNCTION "sms_gateway"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_settings_updated_at" BEFORE UPDATE ON "sms_gateway"."settings" FOR EACH ROW EXECUTE FUNCTION "sms_gateway"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_sms_logs_updated_at" BEFORE UPDATE ON "sms_gateway"."sms_logs" FOR EACH ROW EXECUTE FUNCTION "sms_gateway"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "sms_gateway"."users" FOR EACH ROW EXECUTE FUNCTION "sms_gateway"."update_updated_at_column"();



ALTER TABLE ONLY "inventorymaster"."inventories"
    ADD CONSTRAINT "inventories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "inventorymaster"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "inventorymaster"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "inventorymaster"."profiles"
    ADD CONSTRAINT "profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "inventorymaster"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "inventorymaster"."sales"
    ADD CONSTRAINT "sales_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "inventorymaster"."inventories"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "inventorymaster"."sales"
    ADD CONSTRAINT "sales_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "inventorymaster"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "inventorymaster"."tenants"
    ADD CONSTRAINT "tenants_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_product_access"
    ADD CONSTRAINT "client_product_access_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_product_access"
    ADD CONSTRAINT "client_product_access_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."client_product_access"
    ADD CONSTRAINT "client_product_access_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clients"
    ADD CONSTRAINT "clients_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."global_users"
    ADD CONSTRAINT "global_users_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."global_users"
    ADD CONSTRAINT "global_users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_subscriptions"
    ADD CONSTRAINT "product_subscriptions_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_subscriptions"
    ADD CONSTRAINT "product_subscriptions_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_usage_stats"
    ADD CONSTRAINT "product_usage_stats_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_usage_stats"
    ADD CONSTRAINT "product_usage_stats_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "smartmenu"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "smartmenu"."profiles"
    ADD CONSTRAINT "profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "smartmenu"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "smartmenu"."tenants"
    ADD CONSTRAINT "tenants_client_id_fkey" FOREIGN KEY ("client_id") REFERENCES "public"."clients"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."api_keys"
    ADD CONSTRAINT "api_keys_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "sms_gateway"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."audit_logs"
    ADD CONSTRAINT "audit_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "sms_gateway"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."contacts"
    ADD CONSTRAINT "contacts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "sms_gateway"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."group_members"
    ADD CONSTRAINT "group_members_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "sms_gateway"."contacts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."group_members"
    ADD CONSTRAINT "group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "sms_gateway"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."groups"
    ADD CONSTRAINT "groups_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "sms_gateway"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."settings"
    ADD CONSTRAINT "settings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "sms_gateway"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."sms_logs"
    ADD CONSTRAINT "sms_logs_contact_id_fkey" FOREIGN KEY ("contact_id") REFERENCES "sms_gateway"."contacts"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "sms_gateway"."sms_logs"
    ADD CONSTRAINT "sms_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "sms_gateway"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "sms_gateway"."users"
    ADD CONSTRAINT "users_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Users can access inventories in their tenant" ON "inventorymaster"."inventories" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."client_product_access" "cpa"
     JOIN "public"."products" "p" ON (("cpa"."product_id" = "p"."id")))
  WHERE (("cpa"."user_id" = "auth"."uid"()) AND ("p"."schema_name" = 'inventorymaster'::"text") AND ("cpa"."tenant_id" = "inventories"."tenant_id")))));



CREATE POLICY "Users can access sales in their tenant" ON "inventorymaster"."sales" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."client_product_access" "cpa"
     JOIN "public"."products" "p" ON (("cpa"."product_id" = "p"."id")))
  WHERE (("cpa"."user_id" = "auth"."uid"()) AND ("p"."schema_name" = 'inventorymaster'::"text") AND ("cpa"."tenant_id" = "sales"."tenant_id")))));



CREATE POLICY "Users can access their profile" ON "inventorymaster"."profiles" TO "authenticated" USING ((("id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."client_product_access" "cpa"
     JOIN "public"."products" "p" ON (("cpa"."product_id" = "p"."id")))
  WHERE (("cpa"."user_id" = "auth"."uid"()) AND ("p"."schema_name" = 'inventorymaster'::"text") AND ("cpa"."tenant_id" = "profiles"."tenant_id") AND ("cpa"."role" = ANY (ARRAY['owner'::"text", 'admin'::"text"])))))));



CREATE POLICY "Users can access their tenant data" ON "inventorymaster"."tenants" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM ("public"."client_product_access" "cpa"
     JOIN "public"."products" "p" ON (("cpa"."product_id" = "p"."id")))
  WHERE (("cpa"."user_id" = "auth"."uid"()) AND ("p"."schema_name" = 'inventorymaster'::"text") AND ("cpa"."tenant_id" = "tenants"."id")))));



ALTER TABLE "inventorymaster"."inventories" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "inventorymaster"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "inventorymaster"."sales" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "inventorymaster"."tenants" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "Anyone can view active products" ON "public"."products" FOR SELECT TO "authenticated", "anon" USING (("is_active" = true));



CREATE POLICY "Client owners can update their client" ON "public"."clients" FOR UPDATE TO "authenticated" USING (("owner_id" = "auth"."uid"()));



CREATE POLICY "Users can view subscriptions of their client" ON "public"."product_subscriptions" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."global_users"
  WHERE (("global_users"."id" = "auth"."uid"()) AND ("global_users"."client_id" = "product_subscriptions"."client_id")))));



CREATE POLICY "Users can view their own access" ON "public"."client_product_access" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can view their own client" ON "public"."clients" FOR SELECT TO "authenticated" USING ((("owner_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."global_users"
  WHERE (("global_users"."id" = "auth"."uid"()) AND ("global_users"."client_id" = "clients"."id"))))));



CREATE POLICY "Users can view their own profile" ON "public"."global_users" TO "authenticated" USING (("id" = "auth"."uid"()));



ALTER TABLE "public"."client_product_access" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."clients" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."global_users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_subscriptions" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_usage_stats" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "sms_gateway"."api_keys" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "sms_gateway"."audit_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "sms_gateway"."contacts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "sms_gateway"."group_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "sms_gateway"."groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "sms_gateway"."settings" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "sms_gateway"."sms_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "sms_gateway"."users" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "inventorymaster" TO "authenticated";
GRANT USAGE ON SCHEMA "inventorymaster" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT USAGE ON SCHEMA "smartmenu" TO "authenticated";
GRANT USAGE ON SCHEMA "smartmenu" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."add_user_to_client_product"("p_user_id" "uuid", "p_client_id" "uuid", "p_product_schema" "text", "p_tenant_id" "uuid", "p_role" "text", "p_user_email" "text", "p_user_name" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_user_to_client_product"("p_user_id" "uuid", "p_client_id" "uuid", "p_product_schema" "text", "p_tenant_id" "uuid", "p_role" "text", "p_user_email" "text", "p_user_name" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_user_to_client_product"("p_user_id" "uuid", "p_client_id" "uuid", "p_product_schema" "text", "p_tenant_id" "uuid", "p_role" "text", "p_user_email" "text", "p_user_name" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."create_client"("p_owner_id" "uuid", "p_client_name" "text", "p_client_slug" "text", "p_client_email" "text", "p_owner_name" "text", "p_owner_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."create_client"("p_owner_id" "uuid", "p_client_name" "text", "p_client_slug" "text", "p_client_email" "text", "p_owner_name" "text", "p_owner_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_client"("p_owner_id" "uuid", "p_client_name" "text", "p_client_slug" "text", "p_client_email" "text", "p_owner_name" "text", "p_owner_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_type"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_type"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_type"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_user_type"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_user_type"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_user_type"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_super_admin"("user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_super_admin"("user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_super_admin"("user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."log_usage"("p_product_schema" "text", "p_tenant_id" "uuid", "p_client_id" "uuid", "p_action" "text", "p_details" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."log_usage"("p_product_schema" "text", "p_tenant_id" "uuid", "p_client_id" "uuid", "p_action" "text", "p_details" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_usage"("p_product_schema" "text", "p_tenant_id" "uuid", "p_client_id" "uuid", "p_action" "text", "p_details" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."promote_to_super_admin"("user_email" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."promote_to_super_admin"("user_email" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."promote_to_super_admin"("user_email" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."setup_test_admin"("user_email" "text", "user_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."setup_test_admin"("user_email" "text", "user_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."setup_test_admin"("user_email" "text", "user_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."subscribe_client_to_product"("p_client_id" "uuid", "p_product_schema" "text", "p_tenant_name" "text", "p_tenant_slug" "text", "p_plan_type" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."subscribe_client_to_product"("p_client_id" "uuid", "p_product_schema" "text", "p_tenant_name" "text", "p_tenant_slug" "text", "p_plan_type" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."subscribe_client_to_product"("p_client_id" "uuid", "p_product_schema" "text", "p_tenant_name" "text", "p_tenant_slug" "text", "p_plan_type" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."track_product_usage"("p_product_schema" "text", "p_client_id" "uuid", "p_tenant_id" "uuid", "p_metric_name" "text", "p_metric_value" numeric, "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."track_product_usage"("p_product_schema" "text", "p_client_id" "uuid", "p_tenant_id" "uuid", "p_metric_name" "text", "p_metric_value" numeric, "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."track_product_usage"("p_product_schema" "text", "p_client_id" "uuid", "p_tenant_id" "uuid", "p_metric_name" "text", "p_metric_value" numeric, "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_set_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_user_type"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_user_type"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_user_type"() TO "service_role";


















GRANT ALL ON TABLE "inventorymaster"."inventories" TO "service_role";
GRANT ALL ON TABLE "inventorymaster"."inventories" TO "authenticated";



GRANT ALL ON TABLE "inventorymaster"."profiles" TO "service_role";
GRANT ALL ON TABLE "inventorymaster"."profiles" TO "authenticated";



GRANT ALL ON TABLE "inventorymaster"."sales" TO "service_role";
GRANT ALL ON TABLE "inventorymaster"."sales" TO "authenticated";



GRANT ALL ON TABLE "inventorymaster"."tenants" TO "service_role";
GRANT ALL ON TABLE "inventorymaster"."tenants" TO "authenticated";



GRANT ALL ON TABLE "public"."client_product_access" TO "anon";
GRANT ALL ON TABLE "public"."client_product_access" TO "authenticated";
GRANT ALL ON TABLE "public"."client_product_access" TO "service_role";



GRANT ALL ON TABLE "public"."clients" TO "anon";
GRANT ALL ON TABLE "public"."clients" TO "authenticated";
GRANT ALL ON TABLE "public"."clients" TO "service_role";



GRANT ALL ON TABLE "public"."global_users" TO "anon";
GRANT ALL ON TABLE "public"."global_users" TO "authenticated";
GRANT ALL ON TABLE "public"."global_users" TO "service_role";



GRANT ALL ON TABLE "public"."product_subscriptions" TO "anon";
GRANT ALL ON TABLE "public"."product_subscriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."product_subscriptions" TO "service_role";



GRANT ALL ON TABLE "public"."product_usage_stats" TO "anon";
GRANT ALL ON TABLE "public"."product_usage_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."product_usage_stats" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."v_client_overview" TO "anon";
GRANT ALL ON TABLE "public"."v_client_overview" TO "authenticated";
GRANT ALL ON TABLE "public"."v_client_overview" TO "service_role";



GRANT ALL ON TABLE "public"."v_product_overview" TO "anon";
GRANT ALL ON TABLE "public"."v_product_overview" TO "authenticated";
GRANT ALL ON TABLE "public"."v_product_overview" TO "service_role";



GRANT ALL ON TABLE "public"."v_subscription_summary" TO "anon";
GRANT ALL ON TABLE "public"."v_subscription_summary" TO "authenticated";
GRANT ALL ON TABLE "public"."v_subscription_summary" TO "service_role";



GRANT ALL ON TABLE "public"."v_user_access_overview" TO "anon";
GRANT ALL ON TABLE "public"."v_user_access_overview" TO "authenticated";
GRANT ALL ON TABLE "public"."v_user_access_overview" TO "service_role";



GRANT ALL ON TABLE "smartmenu"."profiles" TO "service_role";
GRANT ALL ON TABLE "smartmenu"."profiles" TO "authenticated";



GRANT ALL ON TABLE "smartmenu"."tenants" TO "service_role";
GRANT ALL ON TABLE "smartmenu"."tenants" TO "authenticated";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























RESET ALL;
