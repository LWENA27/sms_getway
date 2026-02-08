import 'package:flutter/services.dart';
import '../contacts/contact_model.dart';
import '../core/phone_validator.dart';

/// Phonebook Sync Service
///
/// Coordinates native phonebook access via MethodChannel
/// Handles batch sync and duplicate detection
class PhonebookSyncService {
  static const MethodChannel _channel =
      MethodChannel('com.lwenatech.sms_gateway/phonebook');

  /// Check if READ_CONTACTS permission is granted
  static Future<bool> hasPermission() async {
    try {
      final bool? result =
          await _channel.invokeMethod('checkContactsPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request READ_CONTACTS permission
  static Future<bool> requestPermission() async {
    try {
      final bool? result =
          await _channel.invokeMethod('requestContactsPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get all contacts from device phonebook
  static Future<List<PhonebookContact>> getPhonebookContacts() async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod('getPhonebookContacts');

      if (result == null) return [];

      return result.map((contact) {
        return PhonebookContact(
          name: contact['name'] as String? ?? '',
          phoneNumber: contact['phoneNumber'] as String? ?? '',
        );
      }).where((contact) {
        // Filter out contacts without phone numbers
        return contact.phoneNumber.isNotEmpty;
      }).toList();
    } catch (e) {
      throw Exception('Failed to get phonebook contacts: $e');
    }
  }

  /// Validate and normalize phonebook contacts
  static Future<List<PhonebookContactResult>> validateContacts(
    List<PhonebookContact> phonebookContacts,
  ) async {
    final List<PhonebookContactResult> results = [];

    for (int i = 0; i < phonebookContacts.length; i++) {
      final contact = phonebookContacts[i];
      final index = i + 1;

      // Normalize phone number
      final normalized = PhoneValidator.normalize(contact.phoneNumber);

      if (normalized == null) {
        // Invalid phone number
        results.add(PhonebookContactResult(
          contact: contact,
          index: index,
          status: PhonebookSyncStatus.error,
          normalizedPhone: null,
          error: PhoneValidator.getValidationError(contact.phoneNumber),
        ));
      } else {
        // Valid phone number
        results.add(PhonebookContactResult(
          contact: contact,
          index: index,
          status: PhonebookSyncStatus.valid,
          normalizedPhone: normalized,
          error: null,
        ));
      }
    }

    return results;
  }

  /// Detect duplicates against existing contacts
  static Set<String> detectDuplicates({
    required List<PhonebookContactResult> phonebookResults,
    required List<Contact> existingContacts,
  }) {
    // Create set of existing phone numbers (normalized)
    final existingPhones = existingContacts
        .map((c) => PhoneValidator.normalize(c.phoneNumber))
        .where((phone) => phone != null)
        .cast<String>()
        .toSet();

    // Find duplicates in phonebook results
    final duplicates = <String>{};
    for (final result in phonebookResults) {
      if (result.normalizedPhone != null &&
          existingPhones.contains(result.normalizedPhone)) {
        duplicates.add(result.normalizedPhone!);
      }
    }

    return duplicates;
  }

  /// Filter results based on duplicate handling
  static List<PhonebookContactResult> filterDuplicates({
    required List<PhonebookContactResult> results,
    required Set<String> duplicates,
    required bool skipDuplicates,
  }) {
    if (!skipDuplicates) return results;

    return results.where((result) {
      return result.normalizedPhone == null ||
          !duplicates.contains(result.normalizedPhone);
    }).toList();
  }

  /// Convert phonebook contact results to Contact models
  static List<Contact> toContactModels({
    required List<PhonebookContactResult> results,
    required String tenantId,
  }) {
    return results
        .where((r) =>
            r.status == PhonebookSyncStatus.valid && r.normalizedPhone != null)
        .map((r) => Contact(
              id: '', // Will be generated on insert
              tenantId: tenantId,
              userId: '', // Will be set during import
              phoneNumber: r.normalizedPhone!,
              name: r.contact.name.isNotEmpty
                  ? r.contact.name
                  : r.normalizedPhone!,
              firstName: _extractFirstName(r.contact.name),
              lastName: _extractLastName(r.contact.name),
              createdAt: DateTime.now(),
            ))
        .toList();
  }

  /// Extract first name from full name
  static String? _extractFirstName(String fullName) {
    if (fullName.isEmpty) return null;
    final parts = fullName.trim().split(' ');
    return parts.isNotEmpty ? parts.first : null;
  }

  /// Extract last name from full name
  static String? _extractLastName(String fullName) {
    if (fullName.isEmpty) return null;
    final parts = fullName.trim().split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : null;
  }

  /// Get sync summary statistics
  static PhonebookSyncSummary getSummary(
    List<PhonebookContactResult> results,
    Set<String> duplicates,
  ) {
    final total = results.length;
    final valid =
        results.where((r) => r.status == PhonebookSyncStatus.valid).length;
    final errors =
        results.where((r) => r.status == PhonebookSyncStatus.error).length;
    final duplicateCount = duplicates.length;

    return PhonebookSyncSummary(
      total: total,
      valid: valid,
      errors: errors,
      duplicates: duplicateCount,
      successRate: total > 0 ? (valid / total * 100) : 0,
    );
  }
}

/// Phonebook Contact (from device)
class PhonebookContact {
  final String name;
  final String phoneNumber;

  PhonebookContact({
    required this.name,
    required this.phoneNumber,
  });
}

/// Phonebook Contact Result (after validation)
class PhonebookContactResult {
  final PhonebookContact contact;
  final int index;
  final PhonebookSyncStatus status;
  final String? normalizedPhone;
  final String? error;

  PhonebookContactResult({
    required this.contact,
    required this.index,
    required this.status,
    this.normalizedPhone,
    this.error,
  });

  bool get isValid => status == PhonebookSyncStatus.valid;
  bool get hasError => status == PhonebookSyncStatus.error;

  String get displayName => contact.name.isNotEmpty
      ? contact.name
      : (normalizedPhone ?? contact.phoneNumber);
}

/// Phonebook Sync Status
enum PhonebookSyncStatus {
  valid,
  error,
}

/// Phonebook Sync Summary
class PhonebookSyncSummary {
  final int total;
  final int valid;
  final int errors;
  final int duplicates;
  final double successRate;

  PhonebookSyncSummary({
    required this.total,
    required this.valid,
    required this.errors,
    required this.duplicates,
    required this.successRate,
  });
}
