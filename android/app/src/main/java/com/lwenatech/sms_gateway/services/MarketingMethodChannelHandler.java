package com.lwenatech.sms_gateway.services;

import android.content.Context;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

/**
 * Marketing Method Channel Handler
 * 
 * Flutter-to-Android bridge for marketing automation features.
 * Handles MethodChannel calls from Flutter and delegates to MarketingService.
 * 
 * Register this in MainActivity.kt like:
 * 
 * val marketingChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, 
 *                                      "com.lwenatech.sms_gateway/marketing")
 * MarketingMethodChannelHandler.register(marketingChannel, applicationContext)
 */
public class MarketingMethodChannelHandler {
    
    private static final String TAG = "MarketingChannelHandler";
    private MarketingService marketingService;
    
    public MarketingMethodChannelHandler(Context context) {
        this.marketingService = new MarketingService(context);
    }
    
    /**
     * Register method channel handler
     * 
     * @param channel MethodChannel from Flutter
     * @param context Application context
     */
    public static void register(MethodChannel channel, Context context) {
        MarketingMethodChannelHandler handler = new MarketingMethodChannelHandler(context);
        
        channel.setMethodCallHandler((call, result) -> {
            try {
                switch (call.method) {
                    case "enableMarketing":
                        handler.handleEnableMarketing(call, result);
                        break;
                    case "disableMarketing":
                        handler.handleDisableMarketing(result);
                        break;
                    case "isMarketingEnabled":
                        handler.handleIsMarketingEnabled(result);
                        break;
                    case "getMarketingSettings":
                        handler.handleGetSettings(result);
                        break;
                    case "setDailyLimit":
                        handler.handleSetDailyLimit(call, result);
                        break;
                    case "resetDailyCounter":
                        handler.handleResetDailyCounter(result);
                        break;
                    case "getCampaignStats":
                        handler.handleGetCampaignStats(call, result);
                        break;
                    case "canSendToPhone":
                        handler.handleCanSendToPhone(call, result);
                        break;
                    case "getBlockReason":
                        handler.handleGetBlockReason(call, result);
                        break;
                    case "getRemainingQuota":
                        handler.handleGetRemainingQuota(call, result);
                        break;
                    case "addOptOut":
                        handler.handleAddOptOut(call, result);
                        break;
                    case "removeOptOut":
                        handler.handleRemoveOptOut(call, result);
                        break;
                    case "forceCheckNow":
                        handler.handleForceCheckNow(result);
                        break;
                    default:
                        result.notImplemented();
                }
            } catch (Exception e) {
                android.util.Log.e(TAG, "Error handling method: " + call.method, e);
                result.error("ERROR", e.getMessage(), null);
            }
        });
    }
    
    private void handleEnableMarketing(MethodCall call, MethodChannel.Result result) {
        String tenantId = call.argument("tenant_id");
        Integer dailyLimit = call.argument("daily_limit");
        String accessToken = call.argument("access_token");
        
        if (tenantId == null) {
            result.error("INVALID_ARGS", "tenant_id is required", null);
            return;
        }
        
        marketingService.enableMarketing(tenantId, 
                                        dailyLimit != null ? dailyLimit : 100,
                                        accessToken);
        result.success(true);
    }
    
    private void handleDisableMarketing(MethodChannel.Result result) {
        marketingService.disableMarketing();
        result.success(true);
    }
    
    private void handleIsMarketingEnabled(MethodChannel.Result result) {
        boolean enabled = marketingService.isMarketingEnabled();
        result.success(enabled);
    }
    
    private void handleGetSettings(MethodChannel.Result result) {
        Map<String, Object> settings = marketingService.getSettings();
        result.success(settings);
    }
    
    private void handleSetDailyLimit(MethodCall call, MethodChannel.Result result) {
        Integer dailyLimit = call.argument("daily_limit");
        
        if (dailyLimit == null) {
            result.error("INVALID_ARGS", "daily_limit is required", null);
            return;
        }
        
        marketingService.setDailyLimit(dailyLimit);
        result.success(true);
    }
    
    private void handleResetDailyCounter(MethodChannel.Result result) {
        marketingService.resetDailyCounter();
        result.success(true);
    }
    
    private void handleGetCampaignStats(MethodCall call, MethodChannel.Result result) {
        String campaignId = call.argument("campaign_id");
        
        if (campaignId == null) {
            result.error("INVALID_ARGS", "campaign_id is required", null);
            return;
        }
        
        Map<String, Integer> stats = marketingService.getCampaignStats(campaignId);
        
        // Convert to Map<String, Object> for Flutter
        Map<String, Object> flutterStats = new HashMap<>();
        for (Map.Entry<String, Integer> entry : stats.entrySet()) {
            flutterStats.put(entry.getKey(), entry.getValue());
        }
        
        result.success(flutterStats);
    }
    
    private void handleCanSendToPhone(MethodCall call, MethodChannel.Result result) {
        String tenantId = call.argument("tenant_id");
        String phoneNumber = call.argument("phone_number");
        
        if (tenantId == null || phoneNumber == null) {
            result.error("INVALID_ARGS", "tenant_id and phone_number are required", null);
            return;
        }
        
        boolean canSend = marketingService.canSendToPhone(tenantId, phoneNumber);
        result.success(canSend);
    }
    
    private void handleGetBlockReason(MethodCall call, MethodChannel.Result result) {
        String tenantId = call.argument("tenant_id");
        String phoneNumber = call.argument("phone_number");
        
        if (tenantId == null || phoneNumber == null) {
            result.error("INVALID_ARGS", "tenant_id and phone_number are required", null);
            return;
        }
        
        String reason = marketingService.getBlockReason(tenantId, phoneNumber);
        result.success(reason);
    }
    
    private void handleGetRemainingQuota(MethodCall call, MethodChannel.Result result) {
        String tenantId = call.argument("tenant_id");
        String phoneNumber = call.argument("phone_number");
        
        if (tenantId == null || phoneNumber == null) {
            result.error("INVALID_ARGS", "tenant_id and phone_number are required", null);
            return;
        }
        
        int quota = marketingService.getRemainingQuota(tenantId, phoneNumber);
        result.success(quota);
    }
    
    private void handleAddOptOut(MethodCall call, MethodChannel.Result result) {
        String tenantId = call.argument("tenant_id");
        String phoneNumber = call.argument("phone_number");
        
        if (tenantId == null || phoneNumber == null) {
            result.error("INVALID_ARGS", "tenant_id and phone_number are required", null);
            return;
        }
        
        marketingService.addOptOut(tenantId, phoneNumber);
        result.success(true);
    }
    
    private void handleRemoveOptOut(MethodCall call, MethodChannel.Result result) {
        String tenantId = call.argument("tenant_id");
        String phoneNumber = call.argument("phone_number");
        
        if (tenantId == null || phoneNumber == null) {
            result.error("INVALID_ARGS", "tenant_id and phone_number are required", null);
            return;
        }
        
        marketingService.removeOptOut(tenantId, phoneNumber);
        result.success(true);
    }
    
    private void handleForceCheckNow(MethodChannel.Result result) {
        marketingService.forceCheckNow();
        result.success(true);
    }
}
