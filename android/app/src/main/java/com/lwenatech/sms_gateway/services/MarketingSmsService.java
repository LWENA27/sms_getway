package com.lwenatech.sms_gateway.services;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.IBinder;
import android.telephony.SmsManager;
import android.util.Log;
import androidx.core.app.NotificationCompat;
import androidx.core.content.ContextCompat;

import com.lwenatech.sms_gateway.MainActivity;
import com.lwenatech.sms_gateway.R;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Foreground Service for sending marketing SMS.
 * This runs with a visible notification, allowing background SMS sending.
 */
public class MarketingSmsService extends Service {
    private static final String TAG = "MarketingSmsService";
    private static final String CHANNEL_ID = "marketing_sms_channel";
    private static final int NOTIFICATION_ID = 2001;

    // Intent extras
    public static final String EXTRA_CONTACT_ID = "contact_id";
    public static final String EXTRA_CAMPAIGN_ID = "campaign_id";
    public static final String EXTRA_PHONE_NUMBER = "phone_number";
    public static final String EXTRA_MESSAGE = "message";
    public static final String EXTRA_TENANT_ID = "tenant_id";

    private NotificationManager notificationManager;
    private int smsSentCount = 0;
    private ExecutorService executorService;

    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "Marketing SMS Service created");
        
        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
        executorService = Executors.newFixedThreadPool(2); // 2 threads for database operations
        createNotificationChannel();
        startForeground(NOTIFICATION_ID, createNotification("Initializing..."));
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent == null) {
            Log.w(TAG, "Received null intent, stopping service");
            stopSelf();
            return START_NOT_STICKY;
        }

        String contactId = intent.getStringExtra(EXTRA_CONTACT_ID);
        String campaignId = intent.getStringExtra(EXTRA_CAMPAIGN_ID);
        String phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER);
        String message = intent.getStringExtra(EXTRA_MESSAGE);
        String tenantId = intent.getStringExtra(EXTRA_TENANT_ID);

        Log.i(TAG, "Processing SMS for: " + phoneNumber);

        // Update notification
        updateNotification("Sending to " + phoneNumber + "...");

        // Send SMS
        boolean success = sendSMS(phoneNumber, message);

        if (success) {
            smsSentCount++;
            updateNotification("Sent " + smsSentCount + " marketing SMS");
            
            // Log success to database
            logMarketingEvent(contactId, campaignId, phoneNumber, message, tenantId, "sent", null);
            
            // Update contact status to 'sent'
            updateContactStatus(contactId, "sent");
        } else {
            // Log failure to database
            logMarketingEvent(contactId, campaignId, phoneNumber, message, tenantId, "failed", "SMS sending failed");
        }

        // Stop service after processing (worker will start new instance for next SMS)
        stopSelf(startId);
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onDestroy() {
        Log.i(TAG, "Marketing SMS Service destroyed");
        if (executorService != null && !executorService.isShutdown()) {
            executorService.shutdown();
        }
        super.onDestroy();
    }

    /**
     * Create notification channel for Android O+
     */
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                CHANNEL_ID,
                "Marketing SMS",
                NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Sends marketing SMS campaigns");
            channel.setShowBadge(false);
            notificationManager.createNotificationChannel(channel);
        }
    }

    /**
     * Create foreground service notification
     */
    private Notification createNotification(String contentText) {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE
        );

        return new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Marketing Automation")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build();
    }

    /**
     * Update the foreground notification
     */
    private void updateNotification(String contentText) {
        Notification notification = createNotification(contentText);
        notificationManager.notify(NOTIFICATION_ID, notification);
    }

    /**
     * Send SMS using SmsManager
     */
    private boolean sendSMS(String phoneNumber, String message) {
        try {
            // Check permission
            if (ContextCompat.checkSelfPermission(this, android.Manifest.permission.SEND_SMS)
                    != PackageManager.PERMISSION_GRANTED) {
                Log.e(TAG, "SEND_SMS permission not granted");
                return false;
            }

            // Get SmsManager
            SmsManager smsManager;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                smsManager = getSystemService(SmsManager.class);
            } else {
                smsManager = SmsManager.getDefault();
            }

            // Send SMS (fire-and-forget)
            smsManager.sendTextMessage(phoneNumber, null, message, null, null);
            
            Log.i(TAG, "✅ SMS sent to: " + phoneNumber);
            return true;

        } catch (SecurityException e) {
            Log.e(TAG, "SecurityException sending SMS: " + e.getMessage());
            return false;
        } catch (Exception e) {
            Log.e(TAG, "Error sending SMS: " + e.getMessage());
            return false;
        }
    }

    /**
     * Log marketing event to database
     */
    private void logMarketingEvent(String contactId, String campaignId, String phoneNumber,
                                   String message, String tenantId, String status, String errorMessage) {
        // Run on background thread to avoid NetworkOnMainThreadException
        executorService.execute(() -> {
            try {
                SupabaseClient supabase = new SupabaseClient(this);
            
            // Load access token for RLS
            SharedPreferences prefs = getSharedPreferences("marketing_prefs", Context.MODE_PRIVATE);
            String accessToken = prefs.getString("access_token", null);
            String userId = prefs.getString("user_id", null);
            if (accessToken != null) {
                supabase.setAuthToken(accessToken);
            }
            
            // Log to unified sms_logs table (single source of truth)
            JSONObject smsLog = new JSONObject();
            smsLog.put("id", java.util.UUID.randomUUID().toString());
            smsLog.put("tenant_id", tenantId);
            smsLog.put("user_id", userId != null ? userId : tenantId); // Use actual user_id if available, fallback to tenantId
            smsLog.put("contact_id", contactId);
            smsLog.put("campaign_id", campaignId);
            smsLog.put("phone_number", phoneNumber);
            smsLog.put("message", message != null ? message : "Marketing Campaign SMS");
            smsLog.put("status", status.equals("sent") ? "sent" : "failed");
            smsLog.put("channel", "marketing"); // Track source as marketing campaign
            if (status.equals("sent")) {
                smsLog.put("sent_at", new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).format(new java.util.Date()));
            }
            if (errorMessage != null) {
                smsLog.put("error_message", errorMessage);
            }
            smsLog.put("created_at", new java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US).format(new java.util.Date()));
            
            JSONArray result = supabase.insert("sms_logs", smsLog);
            Log.d(TAG, "✅ SMS log inserted to unified sms_logs table");
            Log.d(TAG, "✅ Logged " + status + " event for marketing SMS to: " + phoneNumber);

            } catch (Exception e) {
                Log.e(TAG, "Error logging marketing event", e);
                if (e.getMessage() != null) {
                    Log.e(TAG, "Error message: " + e.getMessage());
                }
            }
        });
    }    /**
     * Update contact status to 'sent'
     */
    private void updateContactStatus(String contactId, String status) {
        // Run on background thread to avoid NetworkOnMainThreadException
        executorService.execute(() -> {
            try {
                SupabaseClient supabase = new SupabaseClient(this);
                
                // Load access token for RLS
                SharedPreferences prefs = getSharedPreferences("marketing_prefs", Context.MODE_PRIVATE);
                String accessToken = prefs.getString("access_token", null);
                if (accessToken != null) {
                    supabase.setAuthToken(accessToken);
                }
                
                JSONObject update = new JSONObject();
                update.put("status", status);
                update.put("sent_at", "now()");

                String filter = "id=eq." + contactId;
                JSONArray result = supabase.update("marketing_campaign_contacts", filter, update);
                Log.d(TAG, "Updated contact status to: " + status + ", result: " + result.toString());

            } catch (Exception e) {
                Log.e(TAG, "Error updating contact status", e);
                if (e.getMessage() != null) {
                    Log.e(TAG, "Error message: " + e.getMessage());
                }
            }
        });
    }
}
