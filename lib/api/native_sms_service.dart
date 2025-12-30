import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeSmsService {
  // Platform channel for native SMS sending
  static const platform = MethodChannel('com.lwenatech.sms_gateway/sms');

  /// Send SMS using native Android SMS functionality
  /// Returns true if SMS was sent successfully
  static Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      debugPrint('📱 Sending SMS via native Android to $phoneNumber');
      debugPrint('📝 Message: $message');

      // Call native method
      final result = await platform.invokeMethod<bool>(
        'sendSms',
        {
          'phoneNumber': phoneNumber,
          'message': message,
        },
      );

      if (result == true) {
        debugPrint('✅ SMS sent successfully to $phoneNumber');
        return true;
      } else {
        debugPrint('❌ Failed to send SMS to $phoneNumber');
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Platform error sending SMS: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Error sending SMS: $e');
      return false;
    }
  }

  /// Send bulk SMS to multiple recipients
  /// Returns map with success count and failed phone numbers
  static Future<Map<String, dynamic>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      debugPrint('📱 Sending bulk SMS to ${phoneNumbers.length} recipients');

      final result = await platform.invokeMethod<Map<dynamic, dynamic>>(
        'sendBulkSms',
        {
          'phoneNumbers': phoneNumbers,
          'message': message,
        },
      );

      if (result != null) {
        final successCount = result['successCount'] as int? ?? 0;
        final failedNumbers =
            List<String>.from(result['failedNumbers'] as List? ?? []);

        debugPrint(
            '✅ Bulk SMS completed: $successCount sent, ${failedNumbers.length} failed');
        return {
          'successCount': successCount,
          'failedNumbers': failedNumbers,
          'totalRequested': phoneNumbers.length,
        };
      }

      return {
        'successCount': 0,
        'failedNumbers': phoneNumbers,
        'totalRequested': phoneNumbers.length,
      };
    } on PlatformException catch (e) {
      debugPrint('❌ Platform error sending bulk SMS: ${e.message}');
      return {
        'successCount': 0,
        'failedNumbers': phoneNumbers,
        'totalRequested': phoneNumbers.length,
      };
    } catch (e) {
      debugPrint('❌ Error sending bulk SMS: $e');
      return {
        'successCount': 0,
        'failedNumbers': phoneNumbers,
        'totalRequested': phoneNumbers.length,
      };
    }
  }

  /// Check if SMS permission is granted
  static Future<bool> checkSmsPermission() async {
    try {
      final result = await platform.invokeMethod<bool>('checkSmsPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error checking SMS permission: $e');
      return false;
    }
  }

  /// Request SMS sending permission
  static Future<bool> requestSmsPermission() async {
    try {
      final result = await platform.invokeMethod<bool>('requestSmsPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('❌ Error requesting SMS permission: $e');
      return false;
    }
  }
}
