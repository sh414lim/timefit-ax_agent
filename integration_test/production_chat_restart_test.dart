import 'package:flutter/foundation.dart';
import 'package:integration_test/integration_test.dart';

import 'support/production_chat_loopback_fixture.dart';

void main() {
  if (!kDebugMode ||
      !const bool.fromEnvironment('TIMEFIT_LOCAL_PRODUCTION_FIXTURE')) {
    throw StateError('local_fixture_explicit_debug_opt_in_required');
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerProductionChatLoopbackFixture();
}
