import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/bootstrap.dart';
import '../app/dev_chat_shell.dart';
import 'app_environment.dart';

void runTimeFitBootstrap(AppEnvironment environment) {
  if (!environment.isRunnable) {
    throw StateError('production_configuration_unavailable');
  }

  runTimeFitApp(environment);
}

class TimeFitBootstrapApp extends StatelessWidget {
  const TimeFitBootstrapApp({
    required this.environment,
    this.devDatabaseFactory = openDevChatDatabase,
    this.devAttachmentRootFactory = openDevAttachmentRoot,
    this.devDisposalObserver,
    this.stagingDisposalObserver,
    super.key,
  });

  final AppEnvironment environment;
  final DevChatDatabaseFactory devDatabaseFactory;
  final DevAttachmentRootFactory devAttachmentRootFactory;
  final DevChatDisposalObserver? devDisposalObserver;
  final DevChatDisposalObserver? stagingDisposalObserver;

  @override
  Widget build(BuildContext context) {
    return TimeFitApp(
      environment: environment,
      devDatabaseFactory: devDatabaseFactory,
      devAttachmentRootFactory: devAttachmentRootFactory,
      devDisposalObserver: devDisposalObserver,
      stagingDisposalObserver: stagingDisposalObserver,
    );
  }
}
