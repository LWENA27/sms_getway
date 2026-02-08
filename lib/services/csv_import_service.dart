import 'dart:io';
import 'package:csv/csv.dart';
import '../contacts/contact_model.dart';
import '../core/phone_validator.dart';

/// CSV Import Service
///
/// Handles parsing CSV files and importing contacts with validation
class CsvImportService {
  /// Parse CSV file and return raw data
  ///
  /// Returns a list of rows, where each row is a list of column values
  static Future<List<List<String>>> parseCsvFile(File file) async {
    try {
      final input = await file.readAsString();

      // Use csv package to parse (handles quoted fields, commas in values)
      final csvData = const CsvToListConverter().convert(
        input,
        eol: '\n',
        shouldParseNumbers: false, // Keep all as strings
      );

      // Convert to List<List<String>>
      return csvData.map((row) {
        return row.map((cell) => cell?.toString() ?? '').toList();
      }).toList();
    } catch (e) {
      throw Exception('Failed to parse CSV file: $e');
    }
  }

  /// Get CSV headers (first row)
  static List<String> getHeaders(List<List<String>> csvData) {
    if (csvData.isEmpty) return [];
    return csvData.first;
  }

  /// Get CSV data rows (excluding header)
  static List<List<String>> getDataRows(List<List<String>> csvData) {
    if (csvData.length <= 1) return [];
    return csvData.sublist(1);
  }

  /// Map CSV columns to contact fields
  ///
  /// [csvData] - Raw CSV data
  /// [columnMapping] - Map of field name to column index
  ///   e.g., {'phone': 0, 'firstName': 1, 'lastName': 2}
  ///
  /// Returns list of ImportContactResult with validation status
  static Future<List<ImportContactResult>> mapAndValidate({
    required List<List<String>> csvData,
    required Map<String, int> columnMapping,
    required String tenantId,
  }) async {
    final dataRows = getDataRows(csvData);
    final results = <ImportContactResult>[];

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final rowNumber = i + 2; // +2 because row 1 is header and we're 0-indexed

      try {
        // Extract values from mapped columns
        final phoneIndex = columnMapping['phone'];
        final firstNameIndex = columnMapping['firstName'];
        final lastNameIndex = columnMapping['lastName'];

        if (phoneIndex == null) {
          results.add(ImportContactResult(
            rowNumber: rowNumber,
            status: ImportStatus.error,
            error: 'Phone number column not mapped',
          ));
          continue;
        }

        // Get values (handle missing columns)
        final phoneRaw = phoneIndex < row.length ? row[phoneIndex].trim() : '';
        final firstName = firstNameIndex != null && firstNameIndex < row.length
            ? row[firstNameIndex].trim()
            : '';
        final lastName = lastNameIndex != null && lastNameIndex < row.length
            ? row[lastNameIndex].trim()
            : '';

        // Validate phone number
        final normalizedPhone = PhoneValidator.normalize(phoneRaw);
        if (normalizedPhone == null) {
          results.add(ImportContactResult(
            rowNumber: rowNumber,
            phoneRaw: phoneRaw,
            status: ImportStatus.error,
            error: PhoneValidator.getValidationError(phoneRaw) ??
                'Invalid phone number',
          ));
          continue;
        }

        // Validate name (at least one name required)
        if (firstName.isEmpty && lastName.isEmpty) {
          results.add(ImportContactResult(
            rowNumber: rowNumber,
            phoneRaw: phoneRaw,
            phoneNormalized: normalizedPhone,
            status: ImportStatus.warning,
            error: 'No name provided - will use phone number as name',
          ));
        }

        // Create contact
        final contact = Contact(
          id: '', // Will be generated on insert
          tenantId: tenantId,
          userId: '', // Will be set during import
          phoneNumber: normalizedPhone,
          name: firstName.isNotEmpty ? firstName : normalizedPhone,
          firstName: firstName.isNotEmpty ? firstName : null,
          lastName: lastName.isNotEmpty ? lastName : null,
          createdAt: DateTime.now(),
        );

        results.add(ImportContactResult(
          rowNumber: rowNumber,
          phoneRaw: phoneRaw,
          phoneNormalized: normalizedPhone,
          firstName: firstName.isNotEmpty ? firstName : null,
          lastName: lastName.isNotEmpty ? lastName : null,
          contact: contact,
          status: ImportStatus.valid,
        ));
      } catch (e) {
        results.add(ImportContactResult(
          rowNumber: rowNumber,
          status: ImportStatus.error,
          error: 'Unexpected error: $e',
        ));
      }
    }

    return results;
  }

  /// Detect duplicate contacts
  ///
  /// Compares against existing contacts by phone number
  /// Returns list of phone numbers that already exist
  static Future<Set<String>> detectDuplicates({
    required List<ImportContactResult> importResults,
    required List<Contact> existingContacts,
  }) async {
    final existingPhones = existingContacts.map((c) => c.phoneNumber).toSet();

    final duplicates = <String>{};

    for (final result in importResults) {
      if (result.status == ImportStatus.valid &&
          result.phoneNormalized != null) {
        if (existingPhones.contains(result.phoneNormalized)) {
          duplicates.add(result.phoneNormalized!);
        }
      }
    }

    return duplicates;
  }

  /// Filter out duplicates from import results
  ///
  /// [skipDuplicates] - If true, skip duplicates. If false, include them (will update)
  static List<ImportContactResult> filterDuplicates({
    required List<ImportContactResult> importResults,
    required Set<String> duplicatePhones,
    required bool skipDuplicates,
  }) {
    if (!skipDuplicates) return importResults;

    return importResults.where((result) {
      if (result.status != ImportStatus.valid) return true;
      if (result.phoneNormalized == null) return true;
      return !duplicatePhones.contains(result.phoneNormalized);
    }).toList();
  }

  /// Get import summary statistics
  static ImportSummary getSummary(List<ImportContactResult> results) {
    int total = results.length;
    int valid = results.where((r) => r.status == ImportStatus.valid).length;
    int errors = results.where((r) => r.status == ImportStatus.error).length;
    int warnings =
        results.where((r) => r.status == ImportStatus.warning).length;

    return ImportSummary(
      total: total,
      valid: valid,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Auto-detect column mapping based on header names
  ///
  /// Returns a suggested mapping or empty map if no match found
  static Map<String, int> autoDetectMapping(List<String> headers) {
    final mapping = <String, int>{};

    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase().trim();

      // Phone number patterns
      if (header.contains('phone') ||
          header.contains('mobile') ||
          header.contains('number') ||
          header.contains('tel')) {
        mapping['phone'] = i;
      }

      // First name patterns
      else if (header.contains('first') && header.contains('name')) {
        mapping['firstName'] = i;
      } else if (header == 'firstname' ||
          header == 'first_name' ||
          header == 'fname') {
        mapping['firstName'] = i;
      }

      // Last name patterns
      else if (header.contains('last') && header.contains('name')) {
        mapping['lastName'] = i;
      } else if (header == 'lastname' ||
          header == 'last_name' ||
          header == 'lname') {
        mapping['lastName'] = i;
      }

      // Full name (use as first name)
      else if (header == 'name' && !mapping.containsKey('firstName')) {
        mapping['firstName'] = i;
      }
    }

    return mapping;
  }
}

/// Import status enum
enum ImportStatus {
  valid,
  error,
  warning,
}

/// Result of importing a single contact row
class ImportContactResult {
  final int rowNumber;
  final String? phoneRaw;
  final String? phoneNormalized;
  final String? firstName;
  final String? lastName;
  final Contact? contact;
  final ImportStatus status;
  final String? error;

  ImportContactResult({
    required this.rowNumber,
    this.phoneRaw,
    this.phoneNormalized,
    this.firstName,
    this.lastName,
    this.contact,
    required this.status,
    this.error,
  });

  bool get isValid => status == ImportStatus.valid;
  bool get hasError => status == ImportStatus.error;
  bool get hasWarning => status == ImportStatus.warning;

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return phoneNormalized ?? phoneRaw ?? 'Unknown';
  }
}

/// Summary statistics of import operation
class ImportSummary {
  final int total;
  final int valid;
  final int errors;
  final int warnings;

  ImportSummary({
    required this.total,
    required this.valid,
    required this.errors,
    required this.warnings,
  });

  double get successRate {
    if (total == 0) return 0.0;
    return (valid / total * 100);
  }

  String get summaryText {
    return '$valid valid, $errors errors, $warnings warnings out of $total total';
  }
}
