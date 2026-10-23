import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../src/app_environment.dart';
import 'dev_chat_shell.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class TimeFitApp extends StatefulWidget {
  const TimeFitApp({
    required this.environment,
    this.devDatabaseFactory = openDevChatDatabase,
    this.devDisposalObserver,
    super.key,
  });

  final AppEnvironment environment;
  final DevChatDatabaseFactory devDatabaseFactory;
  final DevChatDisposalObserver? devDisposalObserver;

  @override
  State<TimeFitApp> createState() => _TimeFitAppState();
}

class _TimeFitAppState extends State<TimeFitApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    if (widget.environment != AppEnvironment.dev) {
      _router = createTimeFitRouter(widget.environment);
    }
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.environment == AppEnvironment.dev) {
      return MaterialApp(
        debugShowCheckedModeBanner: true,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        title: widget.environment.displayName,
        home: DevChatShell(
          databaseFactory: widget.devDatabaseFactory,
          disposalObserver: widget.devDisposalObserver,
        ),
      );
    }
    return MaterialApp.router(
      debugShowCheckedModeBanner: widget.environment == AppEnvironment.dev,
      routerConfig: _router!,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      title: widget.environment.displayName,
    );
  }
}
