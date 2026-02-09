package com.lwenatech.sms_gateway.services;

import android.content.Context;

/**
 * Frequency Tracker Service
 * 
 * Enforces anti-spam frequency limits for marketing SMS.
 * 
 * Rules:
 * - Max 2 SMS per phone number per 30 days (rolling window)
 * - Max 100 SMS per tenant per day (configurable)
 * - Respects opt-out list
 * 
 * This service is called BEFORE sending any marketing SMS.
 * It performs all safety checks to ensure compliance.
 * 
 * Design:
 * - Uses event-based tracking (marketing_frequency_events table)
 * - Rolling 30-day window (not calendar month)
 * - Fail-safe: returns false on database errors
 */
public class FrequencyTrackerService {
    
    private static final String TAG = "FrequencyTrackerService";
    private CampaignRepository repository;
    
    public FrequencyTrackerService(Context context) {
        this.repository = new CampaignRepository(context);
    }
    
    /**
     * Check if SMS can be sent to phone number
     * 
     * Performs ALL safety checks:
     * 1. Marketing enabled for tenant?
     * 2. Phone number opted out?
     * 3. Frequency limit exceeded? (2/30 days)
     * 4. Daily tenant limit exceeded?
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Recipient phone
     * @return true if SMS can be sent, false otherwise
     */
    public boolean canSendSms(String tenantId, String phoneNumber) {
        try {
            android.util.Log.d(TAG, "Checking if can send to: " + phoneNumber);
            
            // Check 1: Marketing enabled?
            if (!isMarketingEnabled(tenantId)) {
                android.util.Log.i(TAG, "Marketing disabled for tenant");
                return false;
            }
            
            // Check 2: Opted out?
            if (repository.isOptedOut(tenantId, phoneNumber)) {
                android.util.Log.i(TAG, "Phone number opted out: " + phoneNumber);
                return false;
            }
            
            // Check 3: Frequency limit?
            if (repository.exceedsFrequencyLimit(tenantId, phoneNumber)) {
                android.util.Log.i(TAG, "Frequency limit exceeded: " + phoneNumber);
                return false;
            }
            
            // Check 4: Daily limit?
            if (isDailyLimitReached(tenantId)) {
                android.util.Log.i(TAG, "Daily limit reached for tenant");
                return false;
            }
            
            android.util.Log.d(TAG, "All checks passed - can send SMS");
            return true;
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error in canSendSms: " + e.getMessage(), e);
            return false; // Fail safe
        }
    }
    
    /**
     * Check if marketing is enabled for tenant
     */
    private boolean isMarketingEnabled(String tenantId) {
        try {
            var settings = repository.getMarketingSettings(tenantId);
            return (boolean) settings.getOrDefault("enabled", false);
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error checking marketing enabled: " + e.getMessage(), e);
            return false;
        }
    }
    
    /**
     * Check if daily limit reached for tenant
     */
    private boolean isDailyLimitReached(String tenantId) {
        try {
            var settings = repository.getMarketingSettings(tenantId);
            int dailyLimit = (int) settings.getOrDefault("daily_limit", 100);
            int dailyCount = repository.getDailySmsCount(tenantId);
            
            android.util.Log.d(TAG, String.format("Daily usage: %d/%d", dailyCount, dailyLimit));
            
            return dailyCount >= dailyLimit;
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error checking daily limit: " + e.getMessage(), e);
            return true; // Fail safe: assume limit reached
        }
    }
    
    /**
     * Get remaining SMS quota for phone number
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to check
     * @return Number of SMS remaining (0-2)
     */
    public int getRemainingQuota(String tenantId, String phoneNumber) {
        try {
            android.util.Log.d(TAG, "Calculating remaining quota: " + phoneNumber);
            int count = repository.getFrequencyCount(tenantId, phoneNumber);
            int remaining = 2 - count;
            return Math.max(0, remaining);
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error calculating quota: " + e.getMessage(), e);
            return 0; // Fail safe
        }
    }
    
    /**
     * Get reason why SMS cannot be sent (for debugging)
     * 
     * @param tenantId Tenant UUID
     * @param phoneNumber Phone to check
     * @return Human-readable reason, or null if can send
     */
    public String getBlockReason(String tenantId, String phoneNumber) {
        try {
            if (!isMarketingEnabled(tenantId)) {
                return "Marketing disabled for this tenant";
            }
            
            if (repository.isOptedOut(tenantId, phoneNumber)) {
                return "Phone number has opted out";
            }
            
            if (repository.exceedsFrequencyLimit(tenantId, phoneNumber)) {
                return "Frequency limit exceeded (2 SMS per 30 days)";
            }
            
            if (isDailyLimitReached(tenantId)) {
                return "Daily tenant limit reached";
            }
            
            return null; // Can send
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error getting block reason: " + e.getMessage(), e);
            return "Error checking status: " + e.getMessage();
        }
    }
}
