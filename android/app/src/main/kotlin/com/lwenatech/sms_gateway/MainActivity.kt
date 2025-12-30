package com.lwenatech.sms_gateway

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lwenatech.sms_gateway/sms"
    private val SMS_SENT = "SMS_SENT"
    private val SMS_DELIVERED = "SMS_DELIVERED"
    private var sentCount = 0
    private var failedNumbers = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")
                    val message = call.argument<String>("message")
                    if (phoneNumber != null && message != null) {
                        sendSms(phoneNumber, message, result)
                    } else {
                        result.error("INVALID_ARGS", "Phone number or message is null", null)
                    }
                }
                "sendBulkSms" -> {
                    val phoneNumbers = call.argument<List<String>>("phoneNumbers")
                    val message = call.argument<String>("message")
                    if (phoneNumbers != null && message != null) {
                        sendBulkSms(phoneNumbers, message, result)
                    } else {
                        result.error("INVALID_ARGS", "Phone numbers or message is null", null)
                    }
                }
                "checkSmsPermission" -> {
                    val hasPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPermission)
                }
                "requestSmsPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.SEND_SMS),
                            1001
                        )
                        result.success(true)
                    } else {
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendSms(phoneNumber: String, message: String, result: MethodChannel.Result) {
        try {
            // Check permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                return
            }

            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            // Create PendingIntent for SMS_SENT
            val sentIntent = Intent(SMS_SENT)
            val sentPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.getBroadcast(
                    this, 0, sentIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            } else {
                @Suppress("DEPRECATION")
                PendingIntent.getBroadcast(this, 0, sentIntent, PendingIntent.FLAG_UPDATE_CURRENT)
            }

            // Send SMS
            smsManager.sendTextMessage(phoneNumber, null, message, sentPendingIntent, null)
            result.success(true)
        } catch (e: Exception) {
            result.error("SEND_ERROR", e.message, null)
        }
    }

    private fun sendBulkSms(phoneNumbers: List<String>, message: String, result: MethodChannel.Result) {
        try {
            // Check permission
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.SEND_SMS)
                != PackageManager.PERMISSION_GRANTED
            ) {
                result.error("PERMISSION_DENIED", "SMS permission not granted", null)
                return
            }

            sentCount = 0
            failedNumbers.clear()

            val smsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }

            // Send SMS to each number
            for (phoneNumber in phoneNumbers) {
                try {
                    val sentIntent = Intent(SMS_SENT)
                    sentIntent.putExtra("phoneNumber", phoneNumber)
                    
                    val sentPendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.getBroadcast(
                            this, phoneNumber.hashCode(), sentIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                    } else {
                        @Suppress("DEPRECATION")
                        PendingIntent.getBroadcast(
                            this, phoneNumber.hashCode(), sentIntent,
                            PendingIntent.FLAG_UPDATE_CURRENT
                        )
                    }

                    smsManager.sendTextMessage(phoneNumber, null, message, sentPendingIntent, null)
                    sentCount++
                } catch (e: Exception) {
                    failedNumbers.add(phoneNumber)
                }
            }

            val resultMap = mapOf(
                "successCount" to sentCount,
                "failedNumbers" to failedNumbers
            )
            result.success(resultMap)
        } catch (e: Exception) {
            result.error("SEND_ERROR", e.message, null)
        }
    }
}
