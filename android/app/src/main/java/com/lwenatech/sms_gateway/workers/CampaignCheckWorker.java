package com.lwenatech.sms_gateway.workers;

import android.content.Context;
import android.content.SharedPreferences;
import androidx.annotation.NonNull;
import androidx.work.Constraints;
import androidx.work.Data;
import androidx.work.NetworkType;
import androidx.work.OneTimeWorkRequest;
import androidx.work.WorkManager;
import androidx.work.Worker;
import androidx.work.WorkerParameters;
import java.util.concurrent.TimeUnit;
import com.lwenatech.sms_gateway.services.CampaignRepository;

/**
 * Campaign Check Worker
 * 
 * Runs every 30 minutes (scheduled by MarketingCoordinator).
 * Checks if campaigns need processing and schedules individual SMS workers.
 * 
 * Flow:
 * 1. Check if marketing automation is enabled
 * 2. Check if daily limit has been reached
 * 3. Fetch batch of pending contacts (max 10)
 * 4. For each contact, schedule SendMarketingSmsWorker with staggered delays
 * 
 * Critical Design:
 * - Does NOT send SMS directly
 * - Does NOT use Thread.sleep()
 * - Schedules OneTimeWorkRequests with delays for rate limiting
 * - Battery-efficient (quick execution, system handles delays)
 */
public class CampaignCheckWorker extends Worker {
    
    private static final String TAG = "CampaignCheckWorker";
    private static final String PREFS_NAME = "marketing_prefs";
    
    public CampaignCheckWorker(
        @NonNull Context context,
        @NonNull WorkerParameters params
    ) {
        super(context, params);
    }
    
    @NonNull
    @Override
    public Result doWork() {
        Context context = getApplicationContext();
        
        try {
            android.util.Log.i(TAG, "Campaign check started");
            
            // Step 1: Check if marketing automation is enabled
            if (!isMarketingEnabled(context)) {
                android.util.Log.i(TAG, "Marketing automation disabled - skipping");
                return Result.success();
            }
            
            // Step 2: Check daily limit
            if (isDailyLimitReached(context)) {
                android.util.Log.i(TAG, "Daily limit reached - skipping");
                return Result.success();
            }
            
            // Step 3: Get current tenant ID
            String tenantId = getCurrentTenantId(context);
            if (tenantId == null) {
                android.util.Log.w(TAG, "No tenant ID found");
                return Result.failure();
            }
            
            // Step 4: Calculate remaining capacity for today
            int dailyLimit = getDailyLimit(context);
            int todayCount = getTodayCount(context);
            int remainingCapacity = Math.max(0, dailyLimit - todayCount);
            
            if (remainingCapacity == 0) {
                android.util.Log.i(TAG, "No remaining capacity today (" + todayCount + "/" + dailyLimit + ")");
                return Result.success();
            }
            
            android.util.Log.i(TAG, "Remaining capacity: " + remainingCapacity + " (sent: " + todayCount + "/" + dailyLimit + ")");
            
            // Step 5: Fetch pending campaign contacts from Supabase (up to remaining capacity)
            CampaignRepository repository = new CampaignRepository(context);
            java.util.List<java.util.Map<String, String>> pendingContacts = 
                repository.getPendingContacts(tenantId, remainingCapacity);
            
            if (pendingContacts == null || pendingContacts.isEmpty()) {
                android.util.Log.i(TAG, "No pending contacts - skipping");
                return Result.success();
            }
            
            android.util.Log.i(TAG, "Found " + pendingContacts.size() + " pending contacts");
            
            // Step 6: Schedule individual SMS workers with staggered delays
            scheduleSmsWorkers(context, tenantId, pendingContacts);
            
            android.util.Log.i(TAG, "✅ Scheduled " + pendingContacts.size() + " SMS workers for delivery");
            return Result.success();
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error in campaign check: " + e.getMessage(), e);
            return Result.retry(); // Retry on error
        }
    }
    
    /**
     * Check if marketing automation is enabled in settings
     */
    private boolean isMarketingEnabled(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getBoolean("marketing_enabled", false);
    }
    
    /**
     * Check if daily sending limit has been reached
     */
    private boolean isDailyLimitReached(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        
        int dailyLimit = prefs.getInt("daily_limit", 100);
        int dailySentCount = prefs.getInt("daily_sent_count", 0);
        
        // Check if we need to reset counter (new day)
        String lastResetDate = prefs.getString("last_reset_date", "");
        String today = java.time.LocalDate.now().toString();
        
        if (!today.equals(lastResetDate)) {
            // New day - reset counter
            SharedPreferences.Editor editor = prefs.edit();
            editor.putInt("daily_sent_count", 0);
            editor.putString("last_reset_date", today);
            editor.apply();
            dailySentCount = 0;
        }
        
        return dailySentCount >= dailyLimit;
    }
    
    /**
     * Get daily sending limit from settings
     */
    private int getDailyLimit(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getInt("daily_limit", 100);
    }
    
    /**
     * Get count of SMS sent today
     */
    private int getTodayCount(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        
        // Check if we need to reset counter (new day)
        String lastResetDate = prefs.getString("last_reset_date", "");
        String today = java.time.LocalDate.now().toString();
        
        if (!today.equals(lastResetDate)) {
            // New day - reset counter
            SharedPreferences.Editor editor = prefs.edit();
            editor.putInt("daily_sent_count", 0);
            editor.putString("last_reset_date", today);
            editor.apply();
            return 0;
        }
        
        return prefs.getInt("daily_sent_count", 0);
    }
    
    /**
     * Get current tenant ID from SharedPreferences
     */
    private String getCurrentTenantId(Context context) {
        // Get tenant ID from input data first (for forceCheckNow calls)
        String tenantIdFromInput = getInputData().getString("tenant_id");
        if (tenantIdFromInput != null) {
            return tenantIdFromInput;
        }
        
        // Fallback to marketing_prefs (for periodic scheduled work)
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getString("tenant_id", null);
    }
    
    /**
     * Schedule individual SMS workers with staggered delays
     * 
     * CRITICAL: This uses OneTimeWorkRequest with delays (NO Thread.sleep)
     * 
     * Rate limiting: 30-60 seconds between sends
     * Each worker sends ONE SMS only
     */
    private void scheduleSmsWorkers(Context context, String tenantId, 
                                    java.util.List<java.util.Map<String, String>> contacts) {
        WorkManager workManager = WorkManager.getInstance(context);
        
        android.util.Log.i(TAG, "Scheduling " + contacts.size() + " SMS workers");
        
        for (int i = 0; i < contacts.size(); i++) {
            java.util.Map<String, String> contact = contacts.get(i);
            
            // Calculate staggered delay (30-60 seconds per contact)
            long baseDelay = 30; // Base 30 seconds
            long randomDelay = (long) (Math.random() * 30); // Random 0-30 seconds
            long totalDelay = baseDelay + randomDelay;
            long delaySeconds = totalDelay * i; // Multiply by index for staggered sends
            
            // Extract campaign data
            String campaignId = contact.get("campaign_id");
            String phoneNumber = contact.get("phone_number");
            String firstName = contact.get("first_name");
            String lastName = contact.get("last_name");
            
            // Extract campaign message template (now directly available in the map)
            String messageTemplate = contact.get("message_template");
            if (messageTemplate == null) {
                messageTemplate = "";
            }
            
            // Render message with contact name
            String renderedMessage = renderMessage(messageTemplate, firstName, lastName);
            
            // Build input data for worker
            Data inputData = new Data.Builder()
                .putString("tenant_id", tenantId)
                .putString("campaign_id", campaignId)
                .putString("campaign_contact_id", (String) contact.get("id"))
                .putString("contact_id", (String) contact.get("contact_id"))
                .putString("phone_number", phoneNumber)
                .putString("message", renderedMessage)
                .putString("first_name", firstName)
                .putString("last_name", lastName)
                .build();
            
            // Set constraints
            Constraints constraints = new Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build();
            
            // Create OneTimeWorkRequest with delay
            OneTimeWorkRequest smsWork = new OneTimeWorkRequest.Builder(SendMarketingSmsWorker.class)
                .setInputData(inputData)
                .setInitialDelay(delaySeconds, TimeUnit.SECONDS) // CRITICAL: System-managed delay
                .setConstraints(constraints)
                .addTag("marketing_sms")
                .build();
            
            // Enqueue the work
            workManager.enqueue(smsWork);
            
            android.util.Log.d(TAG, "Scheduled SMS #" + (i+1) + " to " + phoneNumber + 
                              " with " + delaySeconds + "s delay");
        }
    }
    
    /**
     * Render message template with contact variables
     */
    private String renderMessage(String template, String firstName, String lastName) {
        if (template == null) return "";
        
        String rendered = template;
        if (firstName != null) {
            rendered = rendered.replace("{{first_name}}", firstName);
        }
        if (lastName != null) {
            rendered = rendered.replace("{{last_name}}", lastName);
        }
        return rendered;
    }
}
