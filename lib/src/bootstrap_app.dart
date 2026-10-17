import 'package:flutter/material.dart';

import 'app_environment.dart';

void runTimeFitBootstrap(AppEnvironment environment) {
  if (!environment.isRunnable) {
    throw StateError('production_configuration_unavailable');
  }

  runApp(TimeFitBootstrapApp(environment: environment));
}

class TimeFitBootstrapApp extends StatelessWidget {
  const TimeFitBootstrapApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: environment == AppEnvironment.dev,
      home: Scaffold(body: Center(child: Text(environment.displayName))),
      title: environment.displayName,
    );
  }
}
