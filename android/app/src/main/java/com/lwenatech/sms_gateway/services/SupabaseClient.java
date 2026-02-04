package com.lwenatech.sms_gateway.services;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Supabase Client for Android
 * 
 * Lightweight REST client for Supabase database operations.
 * Uses HttpURLConnection for zero external dependencies.
 * 
 * Configuration:
 * - SUPABASE_URL: https://kzjgdeqfmxkmpmadtbpb.supabase.co
 * - SUPABASE_ANON_KEY: From constants.dart
 * 
 * Usage:
 * SupabaseClient client = new SupabaseClient(context);
 * JSONArray results = client.select("marketing_campaigns", "status=eq.scheduled");
 */
public class SupabaseClient {
    
    private static final String TAG = "SupabaseClient";
    
    // Configuration from Flutter constants.dart
    private static final String SUPABASE_URL = "https://kzjgdeqfmxkmpmadtbpb.supabase.co";
    private static final String SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6amdkZXFmbXhrbXBtYWR0YnBiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyOTk3NjQsImV4cCI6MjA2NDg3NTc2NH0.NTEzbvVCQ_vNTJPS5bFPSOm5XNRjUrFpSUPEWQDm434";
    
    private static final String REST_API_URL = SUPABASE_URL + "/rest/v1";
    private static final int TIMEOUT_MS = 30000; // 30 seconds
    
    private Context context;
    private String authToken; // User JWT token (optional, defaults to anon key)
    
    public SupabaseClient(Context context) {
        this.context = context;
        this.authToken = SUPABASE_ANON_KEY; // Default to anon key
    }
    
    /**
     * Set user authentication token
     * Call this after user logs in to use RLS policies
     */
    public void setAuthToken(String token) {
        this.authToken = token;
    }
    
    /**
     * SELECT query
     * 
     * @param table Table name (e.g. "marketing_campaigns")
     * @param filter PostgREST filter (e.g. "status=eq.scheduled")
     * @return JSONArray of results
     */
    public JSONArray select(String table, String filter) throws Exception {
        String endpoint = REST_API_URL + "/" + table;
        if (filter != null && !filter.isEmpty()) {
            endpoint += "?" + filter;
        }
        
        String response = makeRequest("GET", endpoint, null);
        return new JSONArray(response);
    }
    
    /**
     * INSERT query
     * 
     * @param table Table name
     * @param data JSON object or array to insert
     * @return JSONArray of inserted rows (with id if generated)
     */
    public JSONArray insert(String table, JSONObject data) throws Exception {
        String endpoint = REST_API_URL + "/" + table;
        
        String response = makeRequest("POST", endpoint, data.toString());
        return new JSONArray(response);
    }
    
    /**
     * UPDATE query
     * 
     * @param table Table name
     * @param filter PostgREST filter (e.g. "id=eq.123")
     * @param data JSON object with fields to update
     * @return JSONArray of updated rows
     */
    public JSONArray update(String table, String filter, JSONObject data) throws Exception {
        String endpoint = REST_API_URL + "/" + table + "?" + filter;
        
        String response = makeRequest("PATCH", endpoint, data.toString());
        return new JSONArray(response);
    }
    
    /**
     * COUNT query (returns total count)
     * 
     * @param table Table name
     * @param filter PostgREST filter
     * @return Count as integer
     */
    public int count(String table, String filter) throws Exception {
        String endpoint = REST_API_URL + "/" + table + "?select=count";
        if (filter != null && !filter.isEmpty()) {
            endpoint += "&" + filter;
        }
        
        HttpURLConnection conn = null;
        try {
            URL url = new URL(endpoint);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod("HEAD"); // HEAD request for count
            conn.setRequestProperty("apikey", SUPABASE_ANON_KEY);
            conn.setRequestProperty("Authorization", "Bearer " + authToken);
            conn.setRequestProperty("Prefer", "count=exact");
            conn.setConnectTimeout(TIMEOUT_MS);
            conn.setReadTimeout(TIMEOUT_MS);
            
            int responseCode = conn.getResponseCode();
            if (responseCode != 200) {
                throw new Exception("HTTP " + responseCode + ": " + conn.getResponseMessage());
            }
            
            String contentRange = conn.getHeaderField("Content-Range");
            if (contentRange != null && contentRange.contains("/")) {
                String count = contentRange.split("/")[1];
                return Integer.parseInt(count);
            }
            
            return 0;
            
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }
    
    /**
     * Call RPC function
     * 
     * @param functionName Function name (e.g. "can_send_marketing_sms")
     * @param params JSON object with function parameters
     * @return JSONArray or JSONObject result
     */
    public JSONArray rpc(String functionName, JSONObject params) throws Exception {
        String endpoint = REST_API_URL + "/rpc/" + functionName;
        
        String response = makeRequest("POST", endpoint, params.toString());
        
        // Try to parse as array first, fallback to wrapping single object
        try {
            return new JSONArray(response);
        } catch (Exception e) {
            JSONArray arr = new JSONArray();
            arr.put(new JSONObject(response));
            return arr;
        }
    }
    
    /**
     * Make HTTP request to Supabase
     */
    private String makeRequest(String method, String endpoint, String body) throws Exception {
        HttpURLConnection conn = null;
        try {
            android.util.Log.d(TAG, method + " " + endpoint);
            
            URL url = new URL(endpoint);
            conn = (HttpURLConnection) url.openConnection();
            conn.setRequestMethod(method);
            conn.setRequestProperty("apikey", SUPABASE_ANON_KEY);
            conn.setRequestProperty("Authorization", "Bearer " + authToken);
            conn.setRequestProperty("Content-Type", "application/json");
            conn.setRequestProperty("Accept", "application/json");
            conn.setRequestProperty("Accept-Profile", "sms_gateway"); // Use sms_gateway schema
            conn.setRequestProperty("Content-Profile", "sms_gateway"); // Use sms_gateway schema for writes
            conn.setRequestProperty("Prefer", "return=representation"); // Return inserted/updated rows
            conn.setConnectTimeout(TIMEOUT_MS);
            conn.setReadTimeout(TIMEOUT_MS);
            
            // Send body if provided
            if (body != null && (method.equals("POST") || method.equals("PATCH"))) {
                conn.setDoOutput(true);
                OutputStream os = conn.getOutputStream();
                os.write(body.getBytes("UTF-8"));
                os.flush();
                os.close();
            }
            
            // Read response
            int responseCode = conn.getResponseCode();
            
            BufferedReader reader;
            if (responseCode >= 200 && responseCode < 300) {
                reader = new BufferedReader(new InputStreamReader(conn.getInputStream()));
            } else {
                reader = new BufferedReader(new InputStreamReader(conn.getErrorStream()));
            }
            
            StringBuilder response = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                response.append(line);
            }
            reader.close();
            
            String responseStr = response.toString();
            
            if (responseCode >= 200 && responseCode < 300) {
                android.util.Log.d(TAG, "Success: " + responseCode);
                return responseStr;
            } else {
                android.util.Log.e(TAG, "Error " + responseCode + ": " + responseStr);
                throw new Exception("HTTP " + responseCode + ": " + responseStr);
            }
            
        } finally {
            if (conn != null) {
                conn.disconnect();
            }
        }
    }
    
    /**
     * Helper: Convert JSONArray to List<Map<String, String>>
     */
    public static List<Map<String, String>> toMapList(JSONArray jsonArray) throws Exception {
        List<Map<String, String>> list = new ArrayList<>();
        
        for (int i = 0; i < jsonArray.length(); i++) {
            JSONObject obj = jsonArray.getJSONObject(i);
            Map<String, String> map = new HashMap<>();
            
            JSONArray keys = obj.names();
            if (keys != null) {
                for (int j = 0; j < keys.length(); j++) {
                    String key = keys.getString(j);
                    Object value = obj.get(key);
                    map.put(key, value != null ? value.toString() : null);
                }
            }
            
            list.add(map);
        }
        
        return list;
    }
}
