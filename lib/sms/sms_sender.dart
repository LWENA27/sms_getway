/// SMS Sender Service - Android SMS functionality
library;

import 'package:flutter/services.dart';

// Note: This is a template. Implement with actual flutter_sms or sms plugins

class SmsSenderService {
  // ignore: constant_identifier_names
  static const PLATFORM = MethodChannel('com.lwenatech.sms_gateway/sms');

  // ===== SEND SMS =====

  /// Send single SMS
  // Future<bool> sendSms({
  //   required String phoneNumber,
  //   required String message,
  // }) async {
  //   try {
  //     // Validate inputs
  //     if (phoneNumber.isEmpty || message.isEmpty) {
  //       throw Exception('Phone number and message cannot be empty');
  //     }
  //
  //     if (message.length > 160) {
  //       throw Exception('Message exceeds 160 characters');
  //     }
  //
  //     // Format phone number
  //     final formattedPhone = _formatPhoneNumber(phoneNumber);
  //
  //     // Send SMS using platform channel
  //     final result = await PLATFORM.invokeMethod('sendSms', {
  //       'phoneNumber': formattedPhone,
  //       'message': message,
  //     });
  //
  //     return result as bool;
  //   } on PlatformException catch (e) {
  //     print('Failed to send SMS: ${e.message}');
  //     rethrow;
  //   }
  // }

  /// Send bulk SMS
  // Future<Map<String, bool>> sendBulkSms({
  //   required List<String> phoneNumbers,
  //   required String message,
  // }) async {
  //   final results = <String, bool>{};
  //
  //   for (final phoneNumber in phoneNumbers) {
  //     try {
  //       final success = await sendSms(
  //         phoneNumber: phoneNumber,
  //         message: message,
  //       );
  //       results[phoneNumber] = success;
  //     } catch (e) {
  //       results[phoneNumber] = false;
  //       print('Failed to send SMS to $phoneNumber: $e');
  //     }
  //   }
  //
  //   return results;
  // }

  // ===== UTILITY METHODS =====

  /// Format phone number to international format
  static String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-numeric characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // If starts with 0, replace with +255 (Tanzania)
    if (cleaned.startsWith('0')) {
      cleaned = '+255${cleaned.substring(1)}';
    }

    // If doesn't start with +, add +255 (assuming Tanzania)
    if (!cleaned.startsWith('+')) {
      cleaned = '+255$cleaned';
    }

    return cleaned;
  }

  /// Validate phone number format
  static bool validatePhoneNumber(String phoneNumber) {
    final formatted = _formatPhoneNumber(phoneNumber);
    // Tanzania phone numbers: +255 followed by 9 digits
    final tanzaniaPattern = RegExp(r'^\+255\d{9}$');
    // General pattern: + followed by 10-15 digits
    final generalPattern = RegExp(r'^\+\d{10,15}$');

    return tanzaniaPattern.hasMatch(formatted) ||
        generalPattern.hasMatch(formatted);
  }

  /// Validate message
  static bool validateMessage(String message) {
    return message.isNotEmpty && message.length <= 160;
  }

  /// Split long message into multiple SMS
  static List<String> splitMessage(String message) {
    if (message.length <= 160) {
      return [message];
    }

    final messages = <String>[];
    int index = 0;

    while (index < message.length) {
      int endIndex = (index + 160).clamp(0, message.length);
      messages.add(message.substring(index, endIndex));
      index = endIndex;
    }

    return messages;
  }
}

// ===== ANDROID IMPLEMENTATION (Kotlin) =====
/*
// MainActivity.kt or SmsService.kt
package com.lwenatech.sms_gateway

import android.content.Context
import android.telephony.SmsManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.view.FlutterMain

class SmsService(context: Context) {
    private val context = context
    private val smsManager: SmsManager = SmsManager.getDefault()
    
    fun sendSms(phoneNumber: String, message: String): Boolean {
        return try {
            smsManager.sendTextMessage(
                phoneNumber,
                null,
                message,
                null,
                null
            )
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
    
    companion object {
        private const val CHANNEL = "com.lwenatech.sms_gateway/sms"
    }
}

// Setup in MainActivity.kt
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    val smsService = SmsService(this)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.lwenatech.sms_gateway/sms")
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")!!
                    val message = call.argument<String>("message")!!
                    val success = smsService.sendSms(phoneNumber, message)
                    result.success(success)
                }
                else -> result.notImplemented()
            }
        }
}
*/

// ===== REQUIRED ANDROID PERMISSIONS =====
/*
// AndroidManifest.xml
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
*/

// ===== USAGE EXAMPLE =====
/*
// Check if phone number is valid
if (!SmsSenderService.validatePhoneNumber('+255712345678')) {
  print('Invalid phone number');
  return;
}

// Check if message is valid
if (!SmsSenderService.validateMessage(message)) {
  print('Message is empty or too long');
  return;
}

// Send single SMS
try {
  final success = await SmsSenderService.sendSms(
    phoneNumber: '+255712345678',
    message: 'Hello World',
  );
  
  if (success) {
    print('SMS sent successfully');
  }
} catch (e) {
  print('Error: $e');
}

// Send bulk SMS
try {
  final results = await SmsSenderService.sendBulkSms(
    phoneNumbers: ['+255712345678', '+255722345678'],
    message: 'Hello World',
  );
  
  results.forEach((phone, success) {
    print('$phone: ${success ? 'Sent' : 'Failed'}');
  });
} catch (e) {
  print('Error: $e');
}

// Split long message
final parts = SmsSenderService.splitMessage(longMessage);
*/
