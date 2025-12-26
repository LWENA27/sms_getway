-- Fix trigger function to handle columns that might not be explicitly set

CREATE OR REPLACE FUNCTION "sms_gateway"."update_updated_at_column"() RETURNS "trigger"
LANGUAGE "plpgsql"
AS $$
BEGIN
    -- Only set updated_at if the column exists
    IF NEW IS NOT NULL AND (SELECT EXISTS(
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = TG_TABLE_NAME 
        AND table_schema = TG_TABLE_SCHEMA 
        AND column_name = 'updated_at'
    )) THEN
        NEW.updated_at := CURRENT_TIMESTAMP;
    END IF;
    RETURN NEW;
END
$$;

-- Alternatively, simpler approach - just set it unconditionally
CREATE OR REPLACE FUNCTION "sms_gateway"."update_updated_at_column"() RETURNS "trigger"
LANGUAGE "plpgsql"
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END
$$;
