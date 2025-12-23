# Native Android SMS Implementation Guide

## Overview
The SMS Gateway now uses **native Android SMS sending** through platform channels, allowing automatic SMS delivery without requiring user intervention in the SMS app.

## Architecture

### Dart Side (`lib/api/native_sms_service.dart`)
- **NativeSmsService**: Handles platform channel communication
- **Methods**:
  - `sendSms()`: Send single SMS
  - `sendBulkSms()`: Send SMS to multiple recipients
  - `checkSmsPermission()`: Check if SMS permission is granted
  - `requestSmsPermission()`: Request SMS permission from user

### Kotlin Side (`android/app/src/main/kotlin/com/example/sms_gateway/MainActivity.kt`)
- **Platform Channel**: `com.example.sms_gateway/sms`
- **Methods**:
  - `sendSms`: Send single SMS using Android SmsManager
  - `sendBulkSms`: Send SMS to bulk recipients
  - Uses PendingIntent for tracking delivery status
  - Handles API level compatibility (API 31+)

## SMS Permissions

The app requires the following permissions (already configured in AndroidManifest.xml):

```xml
<uses-permission android:name="android.permission.SEND_SMS" />
<uses-permission android:name="android.permission.READ_SMS" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.INTERNET" />
```

### Runtime Permissions
- SMS permission is requested at runtime using `permission_handler` package
- User must grant permission before SMS can be sent
- Permission check happens in `bulk_sms_screen.dart` before sending

## How It Works

### 1. User Selects SMS Channel
In Settings → SMS Channel:
- **This Phone**: Uses native Android SMS (automatic)
- **QuickSMS**: For future API integration

### 2. User Sends SMS
In Bulk SMS Screen:
1. User enters message and selects recipients
2. Clicks "Send SMS"
3. App checks SMS permission
4. If permission not granted, requests it
5. Calls `NativeSmsService.sendBulkSms()`

### 3. Native Android Execution
```
Dart Code
    ↓
MethodChannel.invokeMethod('sendBulkSms')
    ↓
MainActivity.kt (Kotlin)
    ↓
SmsManager.sendTextMessage()
    ↓
Android System sends SMS
    ↓
Results returned to Dart
```

### 4. Logging
After SMS is sent:
- Success/failure status is returned
- SMS is logged to `sms_logs` table in database
- User sees success dialog with count

## Usage Example

### Send Single SMS
```dart
final result = await NativeSmsService.sendSms(
  phoneNumber: '+234813456789',
  message: 'Hello from SMS Gateway!',
);

if (result) {
  print('SMS sent successfully');
} else {
  print('Failed to send SMS');
}
```

### Send Bulk SMS
```dart
final phoneNumbers = ['+234813456789', '+234909876543'];
final result = await NativeSmsService.sendBulkSms(
  phoneNumbers: phoneNumbers,
  message: 'Welcome to SMS Gateway!',
);

print('Sent: ${result['successCount']}');
print('Failed: ${result['failedNumbers']}');
```

## Error Handling

### Common Errors

1. **PERMISSION_DENIED**
   - Cause: SMS permission not granted
   - Solution: Request permission in app settings

2. **SEND_ERROR**
   - Cause: SMS Manager error (invalid number, no SIM, etc.)
   - Solution: Validate phone numbers, check device SIM status

3. **INVALID_ARGS**
   - Cause: Phone number or message is null
   - Solution: Check that inputs are provided

## Testing

### Manual Testing Steps

1. **Test Single SMS**
   - Open Contacts screen
   - Add a test contact with your phone number
   - Go to Send SMS tab
   - Select the contact
   - Enter test message
   - Click Send
   - Check if SMS received

2. **Test Bulk SMS**
   - Create a group with multiple contacts
   - Select the group in Send SMS
   - Enter test message
   - Click Send
   - Verify SMS received on all numbers

3. **Test Permission Handling**
   - Deny SMS permission when requested
   - Verify error message shown
   - Grant permission in Settings
   - Retry sending

4. **Test Logging**
   - Send SMS and check database
   - Open Logs screen
   - Verify SMS appears with correct status
   - Check that all fields are populated

## Database Logging

After SMS is sent, the following is logged to `sms_logs` table:

```json
{
  "id": "uuid",
  "user_id": "user-uuid",
  "tenant_id": "tenant-uuid",
  "contact_id": "contact-uuid",
  "phone_number": "+234813456789",
  "message": "SMS content",
  "status": "sent|failed",
  "sent_at": "2024-01-23T10:30:00.000Z",
  "created_at": "2024-01-23T10:30:00.000Z"
}
```

## Limitations

1. **Android Only**: Currently only works on Android devices
   - iOS support would require different implementation

2. **Device Requirements**
   - Active SIM card in device
   - Sufficient balance if USSD charges apply
   - SMS service enabled

3. **Rate Limiting**
   - Android may throttle bulk SMS
   - Device may have SMS rate limits
   - Some carriers limit SMS per minute

## Future Enhancements

1. **QuickSMS Integration**
   - Fallback SMS API service
   - Doesn't require device SIM
   - Better for high-volume sending

2. **Delivery Receipts**
   - Track SMS delivery confirmation
   - Update database with delivery status
   - Notify user of failed deliveries

3. **Scheduled SMS**
   - Send SMS at specific time
   - Queue system for large batches
   - Background service for delivery

4. **iOS Support**
   - MessageKit framework integration
   - Different platform channel approach

## Troubleshooting

### SMS Not Sending

**Issue**: App says SMS sent but not received

**Causes & Solutions**:
- Invalid phone number format → Use E.164 format (+2348...)
- Device SIM has no balance → Check account balance
- SMS blocked by carrier → Contact carrier support
- Device SMS not enabled → Check device settings

### Permission Not Being Requested

**Issue**: Permission dialog doesn't appear

**Causes & Solutions**:
- Permission already granted → Check Settings > Apps > Permissions
- API level mismatch → Update targetSdkVersion in build.gradle
- AndroidManifest missing permission → Already configured

### App Crashes When Sending

**Issue**: App crashes/stops working

**Causes & Solutions**:
- Kotlin compilation error → Run `flutter clean && flutter pub get`
- Missing MethodChannel → Verify channel name matches
- Database connection issue → Check Supabase connection

## Support

For issues or questions:
1. Check the log output: `flutter logs`
2. Verify AndroidManifest.xml has SMS permissions
3. Test on physical device (emulator SMS sending is limited)
4. Check database for any error logs
