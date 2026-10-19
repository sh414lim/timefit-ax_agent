import 'package:flutter/material.dart';

import '../app/app.dart';
import '../app/bootstrap.dart';
import 'app_environment.dart';

void runTimeFitBootstrap(AppEnvironment environment) {
  if (!environment.isRunnable) {
    throw StateError('production_configuration_unavailable');
  }

  runTimeFitApp(environment);
}

class TimeFitBootstrapApp extends StatelessWidget {
  const TimeFitBootstrapApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return TimeFitApp(environment: environment);
  }
}
