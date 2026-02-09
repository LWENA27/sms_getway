package com.lwenatech.sms_gateway.services;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Campaign Repository
 * 
 * Handles ALL Supabase data access for marketing automation.
 * This is the ONLY class that communicates with Supabase for marketing features.
 * 
 * Responsibilities:
 * - Query campaigns and contacts
 * - Check opt-out status
 * - Check frequency limits
 * - Log SMS events
 * - Update campaign status
 */
public class CampaignRepository {
    
    private static final String TAG = "CampaignRepository";
    private Context context;
    private SupabaseClient supabase;
    
    public CampaignRepository(Context context) {
        this.context = context;
        this.supabase = new SupabaseClient(context);
        
        // Load access token from SharedPreferences for RLS
        android.content.SharedPreferences prefs = 
            context.getSharedPreferences("marketing_prefs", Context.MODE_PRIVATE);
        String accessToken = prefs.getString("access_token", null);
        if (accessToken != null && !accessToken.isEmpty()) {
            this.supabase.setAuthToken(accessToken);
            android.util.Log.d(TAG, "Loaded access token for RLS");
        }
    }
    
    /**
     * Set user authentication token for RLS policies
     */
    public void setAuthToken(String token) {
        this.supabase.setAuthToken(token);
    }
    
    /**
     * Get pending campaign contacts
     * 
     * Query: Fetch contacts that are:
     * - Campaign status = 'scheduled' or 'in_progress'
     * - Contact status = 'pending'
     * - Scheduled time <= NOW
     * 
     * @param tenantId Tenant UUID
     * @param limit Max contacts to fetch
     * @return List of contact maps
     */
    public List<Map<String, String>> getPendingContacts(String tenantId, int limit) {
        try {
            android.util.Log.i(TAG, "=== Fetching pending contacts ===");
            android.util.Log.i(TAG, "Tenant ID: " + tenantId);
            android.util.Log.i(TAG, "Limit: " + limit);
            
            // Step 1: Get active campaigns for this tenant
            String campaignFilter = "tenant_id=eq." + tenantId + 
                                   "&status=eq.active" +
                                   "&select=id,message_template,activated_at";
            
            android.util.Log.i(TAG, "Campaign query filter: " + campaignFilter);
            JSONArray campaigns = supabase.select("marketing_campaigns", campaignFilter);
            android.util.Log.i(TAG, "Found " + campaigns.length() + " active campaigns");
            
            if (campaigns.length() == 0) {
                android.util.Log.i(TAG, "No active campaigns found");
                return new ArrayList<>();
            }
            
            // Step 2: Build campaign lookup map and collect campaign IDs
            java.util.Map<String, JSONObject> campaignMap = new java.util.HashMap<>();
            java.util.List<String> campaignIdList = new java.util.ArrayList<>();
            for (int i = 0; i < campaigns.length(); i++) {
                JSONObject campaign = campaigns.getJSONObject(i);
                String id = campaign.getString("id");
                campaignMap.put(id, campaign);
                campaignIdList.add(id);
            }
            
            // Step 3: Get pending contacts for these campaigns
            // Fetch contacts up to the requested limit (respecting daily capacity)
            // Note: Supabase has a 1000 row limit per query, so we'll fetch in batches if needed
            String campaignIdsStr = String.join(",", campaignIdList);
            List<Map<String, String>> result = new ArrayList<>();
            int offset = 0;
            int batchSize = 1000; // Supabase max per query
            
            while (result.size() < limit) {
                int remainingNeeded = limit - result.size();
                int fetchSize = Math.min(remainingNeeded, batchSize);
                
                String contactFilter = "campaign_id=in.(" + campaignIdsStr + ")" +
                                      "&status=eq.pending" +
                                      "&select=id,campaign_id,contact_id,phone_number,first_name,last_name" +
                                      "&order=created_at" +
                                      "&limit=" + fetchSize +
                                      "&offset=" + offset;
                
                android.util.Log.d(TAG, "Fetching contacts: limit=" + fetchSize + ", offset=" + offset);
                JSONArray contacts = supabase.select("marketing_campaign_contacts", contactFilter);
                android.util.Log.d(TAG, "Fetched " + contacts.length() + " contacts in this batch");
                
                if (contacts.length() == 0) {
                    // No more contacts to fetch
                    break;
                }
                
                // Step 4: Merge contact data with campaign data
                for (int i = 0; i < contacts.length(); i++) {
                    JSONObject contact = contacts.getJSONObject(i);
                    String campaignId = contact.getString("campaign_id");
                    
                    if (campaignMap.containsKey(campaignId)) {
                        Map<String, String> contactMap = new HashMap<>();
                        contactMap.put("id", contact.optString("id"));
                        contactMap.put("campaign_id", campaignId);
                        String contactId = contact.optString("contact_id", null);
                        if (contactId != null && contactId.isEmpty()) {
                            contactId = null;
                        }
                        contactMap.put("contact_id", contactId);
                        contactMap.put("phone_number", contact.optString("phone_number"));
                        contactMap.put("first_name", contact.optString("first_name"));
                        contactMap.put("last_name", contact.optString("last_name"));
                        
                        // Add campaign details
                        JSONObject campaign = campaignMap.get(campaignId);
                        contactMap.put("message_template", campaign.optString("message_template"));
                        contactMap.put("activated_at", campaign.optString("activated_at"));
                        
                        result.add(contactMap);
                    }
                }
                
                // If we got fewer contacts than requested, we've reached the end
                if (contacts.length() < fetchSize) {
                    break;
                }
                
                offset += contacts.length();
            }
            
            android.util.Log.i(TAG, "Total pending contacts fetched: " + result.size());
            return result;
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error fetching pending contacts: " + e.getMessage(), e);
            return new ArrayList<>();
        }
    }
    
    /**
     * Check if phone number is opted out
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to check
     * @return true if opted out
     */
    public boolean isOptedOut(String tenantId, String phoneNumber) {
        try {
            android.util.Log.d(TAG, "Checking opt-out status: " + phoneNumber);
            
            String filter = "tenant_id=eq." + tenantId + 
                           "&phone_number=eq." + phoneNumber;
            
            int count = supabase.count("marketing_optouts", filter);
            return count > 0;
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error checking opt-out: " + e.getMessage(), e);
            return true; // Fail safe: assume opted out on error
        }
    }
    
    /**
     * Check frequency limit (2 SMS per 30 days)
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to check
     * @return true if limit exceeded
     */
    public boolean exceedsFrequencyLimit(String tenantId, String phoneNumber) {
        try {
            android.util.Log.d(TAG, "Checking frequency limit: " + phoneNumber);
            
            // Count events in last 30 days
            String thirtyDaysAgo = getTimestamp30DaysAgo();
            String filter = "tenant_id=eq." + tenantId + 
                           "&phone_number=eq." + phoneNumber +
                           "&sent_at=gte." + thirtyDaysAgo;
            
            int count = supabase.count("marketing_frequency_events", filter);
            
            android.util.Log.d(TAG, "Frequency count (30 days): " + count + "/2");
            return count >= 2;
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error checking frequency limit: " + e.getMessage(), e);
            return true; // Fail safe: assume limit exceeded on error
        }
    }
    
    /**
     * Get marketing settings for tenant
     * 
     * @param tenantId Tenant UUID
     * @return Settings map (enabled, daily_limit)
     */
    public Map<String, Object> getMarketingSettings(String tenantId) {
        try {
            android.util.Log.d(TAG, "Fetching marketing settings");
            
            String filter = "tenant_id=eq." + tenantId;
            JSONArray results = supabase.select("marketing_settings", filter);
            
            Map<String, Object> settings = new HashMap<>();
            
            if (results.length() > 0) {
                JSONObject row = results.getJSONObject(0);
                settings.put("enabled", row.getBoolean("enabled"));
                settings.put("daily_limit", row.getInt("daily_limit"));
            } else {
                // No settings found - return defaults
                settings.put("enabled", false);
                settings.put("daily_limit", 100);
            }
            
            return settings;
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error fetching settings: " + e.getMessage(), e);
            Map<String, Object> defaults = new HashMap<>();
            defaults.put("enabled", false);
            defaults.put("daily_limit", 100);
            return defaults;
        }
    }
    
    /**
     * Log successful SMS send
     * 
     * @param tenantId Tenant UUID
     * @param campaignId Campaign UUID
     * @param phoneNumber Recipient phone
     * @param message Message sent
     * @param costUsd Cost in USD
     */
    public void logSuccess(String tenantId, String campaignId, String phoneNumber, 
                          String message, double costUsd) {
        try {
            android.util.Log.d(TAG, "Logging success: " + phoneNumber);
            
            // 1. Insert marketing log
            JSONObject logData = new JSONObject();
            logData.put("tenant_id", tenantId);
            logData.put("campaign_id", campaignId);
            logData.put("phone_number", phoneNumber);
            logData.put("message", message);
            logData.put("status", "sent");
            logData.put("cost_usd", costUsd);
            supabase.insert("marketing_logs", logData);
            
            // 2. Update contact status
            JSONObject updateData = new JSONObject();
            updateData.put("status", "sent");
            updateData.put("sent_at", getCurrentTimestamp());
            String filter = "campaign_id=eq." + campaignId + "&phone_number=eq." + phoneNumber;
            supabase.update("marketing_campaign_contacts", filter, updateData);
            
            // 3. Record frequency event
            JSONObject freqData = new JSONObject();
            freqData.put("tenant_id", tenantId);
            freqData.put("phone_number", phoneNumber);
            freqData.put("campaign_id", campaignId);
            freqData.put("message_preview", message.substring(0, Math.min(100, message.length())));
            supabase.insert("marketing_frequency_events", freqData);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error logging success: " + e.getMessage(), e);
        }
    }
    
    /**
     * Log skipped SMS (opt-out, frequency limit, etc.)
     * 
     * @param campaignId Campaign UUID
     * @param phoneNumber Recipient phone
     * @param reason Skip reason
     */
    public void logSkipped(String campaignId, String phoneNumber, String reason) {
        try {
            android.util.Log.d(TAG, "Logging skipped: " + phoneNumber + " - " + reason);
            
            JSONObject updateData = new JSONObject();
            updateData.put("status", "skipped");
            updateData.put("failure_reason", reason);
            String filter = "campaign_id=eq." + campaignId + "&phone_number=eq." + phoneNumber;
            supabase.update("marketing_campaign_contacts", filter, updateData);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error logging skipped: " + e.getMessage(), e);
        }
    }
    
    /**
     * Log failed SMS
     * 
     * @param tenantId Tenant UUID
     * @param campaignId Campaign UUID
     * @param phoneNumber Recipient phone
     * @param error Error message
     */
    public void logFailure(String tenantId, String campaignId, String phoneNumber, String error) {
        try {
            android.util.Log.d(TAG, "Logging failure: " + phoneNumber + " - " + error);
            
            // 1. Insert log
            JSONObject logData = new JSONObject();
            logData.put("tenant_id", tenantId);
            logData.put("campaign_id", campaignId);
            logData.put("phone_number", phoneNumber);
            logData.put("status", "failed");
            logData.put("error_message", error);
            supabase.insert("marketing_logs", logData);
            
            // 2. Update contact
            JSONObject updateData = new JSONObject();
            updateData.put("status", "failed");
            updateData.put("failure_reason", error);
            String filter = "campaign_id=eq." + campaignId + "&phone_number=eq." + phoneNumber;
            supabase.update("marketing_campaign_contacts", filter, updateData);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error logging failure: " + e.getMessage(), e);
        }
    }
    
    /**
     * Update campaign status
     * 
     * @param campaignId Campaign UUID
     * @param status New status (scheduled, in_progress, completed, cancelled)
     */
    public void updateCampaignStatus(String campaignId, String status) {
        try {
            android.util.Log.d(TAG, "Updating campaign status: " + campaignId + " -> " + status);
            
            JSONObject updateData = new JSONObject();
            updateData.put("status", status);
            updateData.put("updated_at", getCurrentTimestamp());
            String filter = "id=eq." + campaignId;
            supabase.update("marketing_campaigns", filter, updateData);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error updating campaign: " + e.getMessage(), e);
        }
    }
    
    /**
     * Get campaign statistics
     * 
     * Uses Supabase aggregation queries to count contacts by status.
     * This avoids the 1000 row limit by using COUNT queries instead of fetching all rows.
     * 
     * @param campaignId Campaign UUID
     * @return Stats map (total, sent, failed, skipped, pending)
     */
    public Map<String, Integer> getCampaignStats(String campaignId) {
        try {
            android.util.Log.d(TAG, "Fetching campaign stats: " + campaignId);
            
            String baseFilter = "campaign_id=eq." + campaignId;
            
            Map<String, Integer> stats = new HashMap<>();
            
            // Use COUNT queries for each status to avoid 1000 row limit
            stats.put("total", supabase.count("marketing_campaign_contacts", baseFilter));
            stats.put("sent", supabase.count("marketing_campaign_contacts", baseFilter + "&status=eq.sent"));
            stats.put("failed", supabase.count("marketing_campaign_contacts", baseFilter + "&status=eq.failed"));
            stats.put("skipped", supabase.count("marketing_campaign_contacts", baseFilter + "&status=eq.skipped"));
            stats.put("pending", supabase.count("marketing_campaign_contacts", baseFilter + "&status=eq.pending"));
            
            android.util.Log.d(TAG, "Campaign stats: " + stats.toString());
            
            return stats;
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error fetching stats: " + e.getMessage(), e);
            return new HashMap<>();
        }
    }
    
    /**
     * Get daily SMS count for tenant
     * 
     * @param tenantId Tenant UUID
     * @return Count of SMS sent today
     */
    public int getDailySmsCount(String tenantId) {
        try {
            android.util.Log.d(TAG, "Fetching daily SMS count");
            
            String today = getTodayDate();
            String filter = "tenant_id=eq." + tenantId + 
                           "&status=eq.sent" +
                           "&sent_at=gte." + today;
            
            return supabase.count("marketing_logs", filter);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error fetching daily count: " + e.getMessage(), e);
            return 0;
        }
    }
    
    // ========== Helper Methods ==========
    
    private String getCurrentTimestamp() {
        return java.time.Instant.now().toString();
    }
    
    private String getTodayDate() {
        return java.time.LocalDate.now().toString() + "T00:00:00";
    }
    
    private String getTimestamp30DaysAgo() {
        return java.time.Instant.now()
            .minus(30, java.time.temporal.ChronoUnit.DAYS)
            .toString();
    }
}
