import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../src/app_environment.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class TimeFitApp extends StatefulWidget {
  const TimeFitApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  State<TimeFitApp> createState() => _TimeFitAppState();
}

class _TimeFitAppState extends State<TimeFitApp> {
  late final GoRouter _router = createTimeFitRouter(widget.environment);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: widget.environment == AppEnvironment.dev,
      routerConfig: _router,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      title: widget.environment.displayName,
    );
  }
}
