import 'package:integration_test/integration_test.dart';

import 'support/chat_fault_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerLocalChatFaultScenarios();
}
