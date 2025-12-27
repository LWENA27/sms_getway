/// Stub implementation - should never be used
library;

import 'package:drift/drift.dart';

DatabaseConnection connect() {
  throw UnsupportedError(
    'No suitable database implementation was found on this platform.',
  );
}
