// SMS API Edge Function - REST API for external systems
// This function handles incoming SMS requests from external systems
// and queues them for processing by the mobile app.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-key",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

interface SmsRequest {
  phone_number: string;
  message: string;
  external_id?: string;
  priority?: number;
  scheduled_at?: string;
  metadata?: Record<string, unknown>;
}

interface BulkSmsRequest {
  phone_numbers: string[];
  message: string;
  external_id?: string;
  priority?: number;
  scheduled_at?: string;
  metadata?: Record<string, unknown>;
}

// Main handler function
async function handler(req: Request): Promise<Response> {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get API key from header

    const apiKey = req.headers.get("x-api-key");
    
    if (!apiKey) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing API key. Include 'x-api-key' header.",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Parse the URL path
    const url = new URL(req.url);
    const path = url.pathname.replace(/^\/sms-api\/?/, "");

    // Route requests
    if (req.method === "POST" && (path === "" || path === "send")) {
      // Single SMS send
      const body: SmsRequest = await req.json();
      
      if (!body.phone_number || !body.message) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Missing required fields: phone_number, message",
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      // Call sms_gateway.submit_sms_request function
      // Try sms_gateway schema first, then fallback to public
      
      let result = await (supabase as any).rpc("submit_sms_request", {
        p_api_key: apiKey,
        p_phone_number: body.phone_number,
        p_message: body.message,
        p_external_id: body.external_id || null,
        p_priority: body.priority || 0,
        p_scheduled_at: body.scheduled_at || null,
        p_metadata: body.metadata || {},
      }, {
        schema: "sms_gateway"
      });
      
      // If sms_gateway doesn't work, try public schema
      if (result.error) {
        result = await (supabase as any).rpc("submit_sms_request", {
          p_api_key: apiKey,
          p_phone_number: body.phone_number,
          p_message: body.message,
          p_external_id: body.external_id || null,
          p_priority: body.priority || 0,
          p_scheduled_at: body.scheduled_at || null,
          p_metadata: body.metadata || {},
        });
      }

      const { data, error } = result;

      if (error) {
        console.error("RPC Error:", error);
        return new Response(
          JSON.stringify({
            success: false,
            error: error.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const responseData = data as { success: boolean; error?: string };
      
      return new Response(JSON.stringify(data), {
        status: responseData.success ? 200 : 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (req.method === "POST" && path === "bulk") {
      // Bulk SMS send
      const body: BulkSmsRequest = await req.json();

      if (!body.phone_numbers || !body.message || !Array.isArray(body.phone_numbers)) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Missing required fields: phone_numbers (array), message",
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      let bulkResult = await supabase.rpc("submit_bulk_sms_request", {
        p_api_key: apiKey,
        p_phone_numbers: body.phone_numbers,
        p_message: body.message,
        p_external_id: body.external_id || null,
        p_priority: body.priority || 0,
        p_scheduled_at: body.scheduled_at || null,
        p_metadata: body.metadata || {},
      }, {
        schema: "sms_gateway"
      });

      // If sms_gateway doesn't work, try public schema
      if (bulkResult.error) {
        bulkResult = await supabase.rpc("submit_bulk_sms_request", {
          p_api_key: apiKey,
          p_phone_numbers: body.phone_numbers,
          p_message: body.message,
          p_external_id: body.external_id || null,
          p_priority: body.priority || 0,
          p_scheduled_at: body.scheduled_at || null,
          p_metadata: body.metadata || {},
        });
      }

      const { data, error } = bulkResult;

      if (error) {
        console.error("RPC Error:", error);
        return new Response(
          JSON.stringify({
            success: false,
            error: error.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const result = data as { success: boolean; error?: string };

      return new Response(JSON.stringify(data), {
        status: result.success ? 200 : 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (req.method === "GET" && path.startsWith("status/")) {
      // Get SMS request status
      const requestId = path.replace("status/", "");

      if (!requestId) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Missing request_id in URL path",
          }),
          {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      let statusResult = await supabase.rpc("get_sms_request_status", {
        p_api_key: apiKey,
        p_request_id: requestId,
      }, {
        schema: "sms_gateway"
      });

      // If sms_gateway doesn't work, try public schema
      if (statusResult.error) {
        statusResult = await supabase.rpc("get_sms_request_status", {
          p_api_key: apiKey,
          p_request_id: requestId,
        });
      }

      const { data, error } = statusResult;

      if (error) {
        console.error("RPC Error:", error);
        return new Response(
          JSON.stringify({
            success: false,
            error: error.message,
          }),
          {
            status: 500,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          }
        );
      }

      const result = data as { success: boolean; error?: string };

      return new Response(JSON.stringify(data), {
        status: result.success ? 200 : 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // API documentation endpoint
    if (req.method === "GET" && (path === "" || path === "docs")) {
      const docs = {
        name: "SMS Gateway API",
        version: "1.0.0",
        description: "REST API for sending SMS via SMS Gateway Pro",
        authentication: "Include 'x-api-key' header with your API key",
        endpoints: {
          "POST /sms-api/send": {
            description: "Send a single SMS",
            body: {
              phone_number: "string (required)",
              message: "string (required)",
              external_id: "string (optional) - Your reference ID",
              priority: "integer (optional) - Higher = more priority",
              scheduled_at: "ISO datetime (optional) - Schedule for future",
              metadata: "object (optional) - Additional data",
            },
          },
          "POST /sms-api/bulk": {
            description: "Send SMS to multiple recipients",
            body: {
              phone_numbers: "string[] (required)",
              message: "string (required)",
              external_id: "string (optional)",
              priority: "integer (optional)",
              scheduled_at: "ISO datetime (optional)",
              metadata: "object (optional)",
            },
          },
          "GET /sms-api/status/:request_id": {
            description: "Get status of an SMS request",
            params: {
              request_id: "UUID of the SMS request",
            },
          },
        },
        rate_limits: {
          requests_per_minute: 100,
          bulk_max_recipients: 1000,
        },
      };

      return new Response(JSON.stringify(docs, null, 2), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({
        success: false,
        error: "Invalid endpoint. GET /sms-api/docs for API documentation.",
      }),
      {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Function error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: "Internal server error",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
}

// Export the handler with bypass for API key authentication
serve(async (req: Request): Promise<Response> => {
  // For API key-based requests, bypass JWT verification
  const apiKey = req.headers.get("x-api-key");
  if (apiKey) {
    // Allow API key requests to proceed without JWT
    return handler(req);
  }
  
  // For other requests, proceed normally (JWT will be verified by Supabase)
  return handler(req);
});
