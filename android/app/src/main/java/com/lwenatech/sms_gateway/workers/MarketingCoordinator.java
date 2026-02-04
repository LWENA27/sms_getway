package com.lwenatech.sms_gateway.workers;

import android.content.Context;
import androidx.work.Constraints;
import androidx.work.ExistingPeriodicWorkPolicy;
import androidx.work.NetworkType;
import androidx.work.PeriodicWorkRequest;
import androidx.work.WorkManager;
import java.util.concurrent.TimeUnit;

/**
 * Marketing Automation Coordinator
 * 
 * Schedules periodic campaign processing using WorkManager.
 * This is the entry point for the Marketing Automation Engine.
 * 
 * Features:
 * - Schedules CampaignCheckWorker every 30 minutes
 * - Ensures battery optimization (no wake locks)
 * - Requires network connection for Supabase sync
 * - Persists across device reboots
 * 
 * Usage:
 *   MarketingCoordinator.scheduleMarketingAutomation(context);
 *   MarketingCoordinator.stopMarketingAutomation(context);
 */
public class MarketingCoordinator {
    
    private static final String WORK_NAME = "marketing_automation";
    private static final String TAG = "MarketingCoordinator";
    
    /**
     * Schedule periodic marketing automation processing
     * 
     * This will check for pending campaigns every 30 minutes and
     * schedule SMS sends as needed.
     * 
     * @param context Application context
     */
    public static void scheduleMarketingAutomation(Context context) {
        // Set constraints for battery optimization
        Constraints constraints = new Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED) // Need internet for Supabase
            .setRequiresBatteryNotLow(true)                // Don't run when battery low
            .build();
        
        // Create periodic work request (every 30 minutes)
        PeriodicWorkRequest workRequest = 
            new PeriodicWorkRequest.Builder(
                CampaignCheckWorker.class,
                30, TimeUnit.MINUTES
            )
            .setConstraints(constraints)
            .addTag(TAG)
            .build();
        
        // Schedule the work (KEEP existing work to avoid duplicates)
        WorkManager.getInstance(context)
            .enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP, // Don't replace if already scheduled
                workRequest
            );
        
        android.util.Log.i(TAG, "Marketing automation scheduled (every 30 minutes)");
    }
    
    /**
     * Stop marketing automation processing
     * 
     * Cancels all scheduled and running marketing workers.
     * This is the "kill switch" for immediate stop.
     * 
     * @param context Application context
     */
    public static void stopMarketingAutomation(Context context) {
        WorkManager workManager = WorkManager.getInstance(context);
        
        // Cancel periodic work
        workManager.cancelUniqueWork(WORK_NAME);
        
        // Cancel any running SMS send workers
        workManager.cancelAllWorkByTag("marketing_sms");
        
        android.util.Log.i(TAG, "Marketing automation stopped");
    }
    
    /**
     * Check if marketing automation is currently scheduled
     * 
     * @param context Application context
     * @return true if scheduled, false otherwise
     */
    public static boolean isScheduled(Context context) {
        // Note: This is a simplified check
        // For full status, query WorkManager work info
        return true; // TODO: Implement actual check
    }
    
    /**
     * Trigger immediate campaign check (manual processing)
     * 
     * Useful for testing or "Process Now" button in UI.
     * 
     * @param context Application context
     */
    public static void triggerImmediateCheck(Context context) {
        Constraints constraints = new Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build();
        
        androidx.work.OneTimeWorkRequest workRequest = 
            new androidx.work.OneTimeWorkRequest.Builder(CampaignCheckWorker.class)
                .setConstraints(constraints)
                .addTag(TAG)
                .build();
        
        WorkManager.getInstance(context).enqueue(workRequest);
        
        android.util.Log.i(TAG, "Immediate campaign check triggered");
    }
}
