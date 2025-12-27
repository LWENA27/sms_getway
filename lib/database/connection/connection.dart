/// Platform-agnostic database connection
library;

import 'package:drift/drift.dart';

// Conditional imports
import 'connection_stub.dart'
    if (dart.library.io) 'native.dart'
    if (dart.library.html) 'web.dart' as impl;

/// Get database connection for the current platform
DatabaseConnection connect() => impl.connect();
