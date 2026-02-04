package com.lwenatech.sms_gateway.services;

import android.content.Context;
import android.content.SharedPreferences;
import androidx.work.WorkManager;
import com.lwenatech.sms_gateway.workers.MarketingCoordinator;

import java.util.List;
import java.util.Map;

/**
 * Marketing Service
 * 
 * High-level business logic for marketing automation.
 * This is the main entry point for Flutter UI to interact with marketing features.
 * 
 * Responsibilities:
 * - Start/stop marketing automation
 * - Configure settings (daily limit, frequency)
 * - Get campaign statistics
 * - Manage opt-outs
 * - Provide status information
 * 
 * Architecture:
 * - Flutter UI calls this service via MethodChannel
 * - This service coordinates Workers and Repository
 * - Workers execute actual SMS sending
 * - Repository handles all database operations
 */
public class MarketingService {
    
    private static final String TAG = "MarketingService";
    private static final String PREFS_NAME = "marketing_prefs";
    
    private Context context;
    private CampaignRepository repository;
    private FrequencyTrackerService frequencyTracker;
    
    public MarketingService(Context context) {
        this.context = context;
        this.repository = new CampaignRepository(context);
        this.frequencyTracker = new FrequencyTrackerService(context);
    }
    
    /**
     * Enable marketing automation
     * 
     * This starts the periodic WorkManager job that checks for campaigns.
     * 
     * @param tenantId Tenant UUID
     * @param dailyLimit Max SMS per day (default 100)
     * @param accessToken User's Supabase JWT token for RLS
     */
    public void enableMarketing(String tenantId, int dailyLimit, String accessToken) {
        try {
            android.util.Log.i(TAG, "Enabling marketing automation");
            
            // Save settings to SharedPreferences
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = prefs.edit();
            editor.putBoolean("marketing_enabled", true);
            editor.putString("tenant_id", tenantId);
            editor.putInt("daily_limit", dailyLimit);
            if (accessToken != null && !accessToken.isEmpty()) {
                editor.putString("access_token", accessToken);
            }
            editor.apply();
            
            // Schedule WorkManager job
            MarketingCoordinator.scheduleMarketingAutomation(context);
            
            android.util.Log.i(TAG, "Marketing automation enabled successfully");
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error enabling marketing: " + e.getMessage(), e);
            throw new RuntimeException("Failed to enable marketing: " + e.getMessage());
        }
    }
    
    /**
     * Disable marketing automation
     * 
     * This stops the periodic WorkManager job.
     * In-flight SMS will complete, but no new campaigns will be processed.
     */
    public void disableMarketing() {
        try {
            android.util.Log.i(TAG, "Disabling marketing automation");
            
            // Update settings
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = prefs.edit();
            editor.putBoolean("marketing_enabled", false);
            editor.apply();
            
            // Stop WorkManager job
            MarketingCoordinator.stopMarketingAutomation(context);
            
            android.util.Log.i(TAG, "Marketing automation disabled successfully");
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error disabling marketing: " + e.getMessage(), e);
            throw new RuntimeException("Failed to disable marketing: " + e.getMessage());
        }
    }
    
    /**
     * Check if marketing is enabled
     * 
     * @return true if enabled
     */
    public boolean isMarketingEnabled() {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getBoolean("marketing_enabled", false);
    }
    
    /**
     * Get current marketing settings
     * 
     * @return Map with keys: enabled, tenant_id, daily_limit, daily_sent_count
     */
    public Map<String, Object> getSettings() {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        
        Map<String, Object> settings = new java.util.HashMap<>();
        settings.put("enabled", prefs.getBoolean("marketing_enabled", false));
        settings.put("tenant_id", prefs.getString("tenant_id", null));
        settings.put("daily_limit", prefs.getInt("daily_limit", 100));
        settings.put("daily_sent_count", prefs.getInt("daily_sent_count", 0));
        
        return settings;
    }
    
    /**
     * Update daily limit
     * 
     * @param dailyLimit New daily limit
     */
    public void setDailyLimit(int dailyLimit) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putInt("daily_limit", dailyLimit);
        editor.apply();
        
        android.util.Log.i(TAG, "Daily limit updated to: " + dailyLimit);
    }
    
    /**
     * Reset daily counter
     * 
     * This is called automatically at midnight by CampaignCheckWorker,
     * but can also be called manually for testing.
     */
    public void resetDailyCounter() {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        SharedPreferences.Editor editor = prefs.edit();
        editor.putInt("daily_sent_count", 0);
        editor.putString("last_reset_date", java.time.LocalDate.now().toString());
        editor.apply();
        
        android.util.Log.i(TAG, "Daily counter reset");
    }
    
    /**
     * Get campaign statistics
     * 
     * @param campaignId Campaign UUID
     * @return Stats map (total, sent, failed, skipped, pending)
     */
    public Map<String, Integer> getCampaignStats(String campaignId) {
        return repository.getCampaignStats(campaignId);
    }
    
    /**
     * Check if phone number can receive SMS
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to check
     * @return true if can send
     */
    public boolean canSendToPhone(String tenantId, String phoneNumber) {
        return frequencyTracker.canSendSms(tenantId, phoneNumber);
    }
    
    /**
     * Get reason why phone cannot receive SMS
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to check
     * @return Human-readable reason, or null if can send
     */
    public String getBlockReason(String tenantId, String phoneNumber) {
        return frequencyTracker.getBlockReason(tenantId, phoneNumber);
    }
    
    /**
     * Get remaining SMS quota for phone number
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to check
     * @return Number of SMS remaining (0-2)
     */
    public int getRemainingQuota(String tenantId, String phoneNumber) {
        return frequencyTracker.getRemainingQuota(tenantId, phoneNumber);
    }
    
    /**
     * Add phone number to opt-out list
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to opt out
     */
    public void addOptOut(String tenantId, String phoneNumber) {
        try {
            android.util.Log.i(TAG, "Adding opt-out: " + phoneNumber);
            
            // TODO: Implement via repository
            // repository.addOptOut(tenantId, phoneNumber);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error adding opt-out: " + e.getMessage(), e);
            throw new RuntimeException("Failed to add opt-out: " + e.getMessage());
        }
    }
    
    /**
     * Remove phone number from opt-out list
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to re-enable
     */
    public void removeOptOut(String tenantId, String phoneNumber) {
        try {
            android.util.Log.i(TAG, "Removing opt-out: " + phoneNumber);
            
            // TODO: Implement via repository
            // repository.removeOptOut(tenantId, phoneNumber);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error removing opt-out: " + e.getMessage(), e);
            throw new RuntimeException("Failed to remove opt-out: " + e.getMessage());
        }
    }
    
    /**
     * Get pending contacts for next batch
     * 
     * @param tenantId Tenant UUID
     * @param limit Max contacts to fetch
     * @return List of contact maps
     */
    public List<Map<String, String>> getPendingContacts(String tenantId, int limit) {
        return repository.getPendingContacts(tenantId, limit);
    }
    
    /**
     * Force immediate campaign check
     * 
     * This bypasses the periodic schedule and runs CampaignCheckWorker immediately.
     * Useful for testing or when user manually triggers a campaign.
     */
    public void forceCheckNow() {
        try {
            android.util.Log.i(TAG, "Forcing immediate campaign check");
            
            // Get tenant ID from preferences
            SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
            String tenantId = prefs.getString("tenant_id", null);
            
            if (tenantId == null) {
                throw new IllegalStateException("Marketing not enabled - no tenant ID");
            }
            
            // Create input data with tenant ID
            androidx.work.Data inputData = new androidx.work.Data.Builder()
                .putString("tenant_id", tenantId)
                .build();
            
            // Schedule CampaignCheckWorker with tenant ID
            androidx.work.OneTimeWorkRequest checkRequest = 
                new androidx.work.OneTimeWorkRequest.Builder(
                    com.lwenatech.sms_gateway.workers.CampaignCheckWorker.class
                )
                .setInputData(inputData)
                .build();
            
            WorkManager.getInstance(context).enqueue(checkRequest);
            
            android.util.Log.i(TAG, "Campaign check scheduled for tenant: " + tenantId);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error forcing check: " + e.getMessage(), e);
            throw new RuntimeException("Failed to force check: " + e.getMessage());
        }
    }
}
