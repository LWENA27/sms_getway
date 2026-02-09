package com.lwenatech.sms_gateway.workers;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.util.Log;
import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.work.Worker;
import androidx.work.WorkerParameters;
import androidx.work.Data;

import com.lwenatech.sms_gateway.services.MarketingSmsService;

import java.util.concurrent.TimeUnit;

/**
 * Send Marketing SMS Worker
 * 
 * Sends a SINGLE marketing SMS to ONE contact.
 * This worker is scheduled by CampaignCheckWorker with a delay for rate limiting.
 * 
 * Flow:
 * 1. Perform final safety checks (opt-out, frequency limit, daily limit)
 * 2. Render message template with contact details
 * 3. Send SMS via SmsManager
 * 4. Log to database (local cache + Supabase sync)
 * 5. Update counters and tracking tables
 * 
 * Critical Design:
 * - Each worker sends ONLY ONE SMS
 * - Rate limiting handled by WorkManager delays (NOT Thread.sleep)
 * - Retries up to 3 times on failure
 * - Logs everything for audit trail
 * 
 * Input Data:
 * - tenant_id: Tenant UUID
 * - campaign_id: Campaign UUID
 * - phone_number: Recipient phone
 * - message: Rendered message (template already processed)
 * - first_name: Contact first name (for template rendering)
 * - last_name: Contact last name (for template rendering)
 */
public class SendMarketingSmsWorker extends Worker {
    
    private static final String TAG = "SendMarketingSmsWorker";
    private static final String PREFS_NAME = "marketing_prefs";
    
    public SendMarketingSmsWorker(
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
            // Get input data
            Data inputData = getInputData();
            String tenantId = inputData.getString("tenant_id");
            String campaignId = inputData.getString("campaign_id");
            String campaignContactId = inputData.getString("campaign_contact_id");
            String contactId = inputData.getString("contact_id");
            String phoneNumber = inputData.getString("phone_number");
            String message = inputData.getString("message");
            String firstName = inputData.getString("first_name");
            String lastName = inputData.getString("last_name");
            
            Log.i(TAG, "Processing SMS for: " + phoneNumber);
            
            // Validate input
            if (tenantId == null || campaignId == null || campaignContactId == null || phoneNumber == null || message == null) {
                Log.e(TAG, "Missing required input data");
                return Result.failure();
            }
            
            // Step 1: Final safety checks
            
            // Check 1: Marketing still enabled?
            if (!isMarketingEnabled(context)) {
                Log.i(TAG, "Marketing disabled - skipping SMS");
                logSkipped(context, campaignId, phoneNumber, "Marketing disabled");
                return Result.success();
            }
            
            // Check 2: Daily limit still OK?
            if (isDailyLimitReached(context)) {
                Log.i(TAG, "Daily limit reached - skipping SMS");
                logSkipped(context, campaignId, phoneNumber, "Daily limit reached");
                return Result.success();
            }
            
            // Check 3: Is number opted out?
            if (isOptedOut(context, tenantId, phoneNumber)) {
                Log.i(TAG, "Number opted out - skipping SMS");
                logSkipped(context, campaignId, phoneNumber, "Opted out");
                return Result.success();
            }
            
            // Check 4: Frequency limit exceeded? (2 SMS per 30 days)
            if (exceedsFrequencyLimit(context, tenantId, phoneNumber)) {
                Log.i(TAG, "Frequency limit exceeded - skipping SMS");
                logSkipped(context, campaignId, phoneNumber, "Frequency limit (2/30 days)");
                return Result.success();
            }
            
            // Step 2: Render message template
            String renderedMessage = renderTemplate(message, firstName, lastName, phoneNumber);
            
            // Step 3: Start Foreground Service to send SMS
            // Note: Foreground Service has permission to send SMS
            Intent serviceIntent = new Intent(context, MarketingSmsService.class);
            serviceIntent.putExtra(MarketingSmsService.EXTRA_CAMPAIGN_CONTACT_ID, campaignContactId);
            serviceIntent.putExtra(MarketingSmsService.EXTRA_CONTACT_ID, contactId);
            serviceIntent.putExtra(MarketingSmsService.EXTRA_CAMPAIGN_ID, campaignId);
            serviceIntent.putExtra(MarketingSmsService.EXTRA_PHONE_NUMBER, phoneNumber);
            serviceIntent.putExtra(MarketingSmsService.EXTRA_MESSAGE, renderedMessage);
            serviceIntent.putExtra(MarketingSmsService.EXTRA_TENANT_ID, tenantId);
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent);
            } else {
                context.startService(serviceIntent);
            }
            
            Log.i(TAG, "✅ Started Foreground Service for SMS to: " + phoneNumber);
            
            // Step 4: Update counters (service will log success/failure)
            incrementDailyCounter(context);
            recordFrequencyEvent(context, tenantId, campaignId, phoneNumber, renderedMessage);
            
            // Step 6: Sync to Supabase (async)
            syncLogsToSupabase(context);
            
            android.util.Log.i(TAG, "SMS sent successfully to: " + phoneNumber);
            return Result.success();
            
        } catch (Exception e) {
            android.util.Log.e(TAG, "Error sending SMS: " + e.getMessage(), e);
            
            // Retry up to 3 times
            if (getRunAttemptCount() < 3) {
                android.util.Log.i(TAG, "Retrying... (attempt " + (getRunAttemptCount() + 1) + "/3)");
                return Result.retry();
            }
            
            // Log failure after 3 attempts
            Data inputData = getInputData();
            logFailure(context, 
                inputData.getString("campaign_id"), 
                inputData.getString("phone_number"), 
                e.getMessage());
            
            return Result.failure();
        }
    }
    
    /**
     * Check if SMS permission is granted
     */
    private boolean hasSmsPermission(Context context) {
        int result = androidx.core.content.ContextCompat.checkSelfPermission(
            context, 
            android.Manifest.permission.SEND_SMS
        );
        return result == android.content.pm.PackageManager.PERMISSION_GRANTED;
    }
    
    /**
     * Check if marketing automation is enabled
     */
    private boolean isMarketingEnabled(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        return prefs.getBoolean("marketing_enabled", false);
    }
    
    /**
     * Check if daily limit has been reached
     */
    private boolean isDailyLimitReached(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        
        int dailyLimit = prefs.getInt("daily_limit", 100);
        int dailySentCount = prefs.getInt("daily_sent_count", 0);
        
        return dailySentCount >= dailyLimit;
    }
    
    /**
     * Check if phone number has opted out
     * TODO: Query Supabase marketing_optouts table
     */
    private boolean isOptedOut(Context context, String tenantId, String phoneNumber) {
        // TODO: Implement Supabase query
        // SELECT EXISTS (
        //   SELECT 1 FROM sms_gateway.marketing_optouts
        //   WHERE tenant_id = ? AND phone_number = ?
        // );
        return false; // Placeholder
    }
    
    /**
     * Check if frequency limit exceeded (2 SMS per 30 days)
     * TODO: Query Supabase marketing_frequency_events table
     */
    private boolean exceedsFrequencyLimit(Context context, String tenantId, String phoneNumber) {
        // TODO: Implement Supabase query
        // SELECT COUNT(*) FROM sms_gateway.marketing_frequency_events
        // WHERE tenant_id = ? AND phone_number = ?
        //   AND sent_at >= NOW() - INTERVAL '30 days'
        // Return true if count >= 2
        return false; // Placeholder
    }
    
    /**
     * Render message template with dynamic fields
     * 
     * Supports: {first_name}, {last_name}, {phone}
     */
    private String renderTemplate(String template, String firstName, String lastName, String phoneNumber) {
        String rendered = template;
        
        if (firstName != null) {
            rendered = rendered.replace("{first_name}", firstName);
        }
        if (lastName != null) {
            rendered = rendered.replace("{last_name}", lastName);
        }
        if (phoneNumber != null) {
            rendered = rendered.replace("{phone}", phoneNumber);
        }
        
        return rendered;
    }
    
    /**
     * Log skipped SMS (opt-out, frequency limit, etc.)
     */
    private void logSkipped(Context context, String campaignId, String phoneNumber, String reason) {
        android.util.Log.d(TAG, "Logging skipped: " + phoneNumber + " - " + reason);
        
        // TODO: Update marketing_campaign_contacts.status = 'skipped'
        // TODO: Set failure_reason = reason
    }
    
    /**
     * Log failed SMS after retries exhausted
     */
    private void logFailure(Context context, String campaignId, String phoneNumber, String error) {
        android.util.Log.d(TAG, "Logging failure: " + phoneNumber + " - " + error);
        
        // TODO: Update marketing_campaign_contacts.status = 'failed'
        // TODO: Set failure_reason = error
        // TODO: Insert into marketing_logs with status = 'failed'
    }
    
    /**
     * Increment daily SMS counter
     */
    private void incrementDailyCounter(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        int currentCount = prefs.getInt("daily_sent_count", 0);
        
        SharedPreferences.Editor editor = prefs.edit();
        editor.putInt("daily_sent_count", currentCount + 1);
        editor.apply();
        
        android.util.Log.d(TAG, "Daily counter: " + (currentCount + 1));
    }
    
    /**
     * Record frequency event for 30-day tracking
     * TODO: Insert into marketing_frequency_events table
     */
    private void recordFrequencyEvent(Context context, String tenantId, String campaignId,
                                     String phoneNumber, String messagePreview) {
        android.util.Log.d(TAG, "Recording frequency event: " + phoneNumber);
        
        // TODO: INSERT INTO sms_gateway.marketing_frequency_events (
        //   tenant_id, phone_number, campaign_id, sent_at, message_preview
        // ) VALUES (?, ?, ?, NOW(), SUBSTRING(?, 1, 100));
    }
    
    /**
     * Sync logs to Supabase (async operation)
     * TODO: Implement batch sync of local logs to Supabase
     */
    private void syncLogsToSupabase(Context context) {
        android.util.Log.d(TAG, "Syncing logs to Supabase (TODO)");
        
        // TODO: Implement async sync
        // 1. Get all unsynced logs from local SQLite
        // 2. Batch insert to Supabase
        // 3. Mark as synced in local DB
    }
}
