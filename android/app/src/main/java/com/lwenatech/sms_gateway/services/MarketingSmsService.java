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

import org.json.JSONObject;

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

    @Override
    public void onCreate() {
        super.onCreate();
        Log.i(TAG, "Marketing SMS Service created");
        
        notificationManager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
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
            logMarketingEvent(contactId, campaignId, phoneNumber, tenantId, "sent", null);
            
            // Update contact status to 'sent'
            updateContactStatus(contactId, "sent");
        } else {
            // Log failure to database
            logMarketingEvent(contactId, campaignId, phoneNumber, tenantId, "failed", "SMS sending failed");
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
                                   String tenantId, String status, String errorMessage) {
        try {
            SupabaseClient supabase = new SupabaseClient(this);
            
            // Load access token for RLS
            SharedPreferences prefs = getSharedPreferences("marketing_prefs", Context.MODE_PRIVATE);
            String accessToken = prefs.getString("access_token", null);
            if (accessToken != null) {
                supabase.setAuthToken(accessToken);
            }
            
            JSONObject log = new JSONObject();
            log.put("tenant_id", tenantId);
            log.put("campaign_id", campaignId);
            log.put("contact_id", contactId);
            log.put("phone_number", phoneNumber);
            log.put("event_type", status);
            if (errorMessage != null) {
                log.put("error_message", errorMessage);
            }

            supabase.insert("marketing_logs", log);
            Log.d(TAG, "Logged " + status + " event for: " + phoneNumber);

        } catch (Exception e) {
            Log.e(TAG, "Error logging marketing event: " + e.getMessage());
        }
    }    /**
     * Update contact status to 'sent'
     */
    private void updateContactStatus(String contactId, String status) {
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
            supabase.update("marketing_campaign_contacts", filter, update);
            Log.d(TAG, "Updated contact status to: " + status);

        } catch (Exception e) {
            Log.e(TAG, "Error updating contact status: " + e.getMessage());
        }
    }
}
