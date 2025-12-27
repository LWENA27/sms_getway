/// Web database connection - STUB (local DB disabled on web)
/// On web, the app uses only Supabase for storage
library;

import 'package:drift/drift.dart';

/// Return a stub connection that throws errors
/// Web platform should use Supabase directly, not local database
DatabaseConnection connect() {
  throw UnsupportedError(
    'Local database not supported on web platform. Use Supabase for data storage.',
  );
}
