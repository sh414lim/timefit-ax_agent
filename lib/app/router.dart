import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../src/app_environment.dart';
import 'theme/tokens.dart';

GoRouter createTimeFitRouter(AppEnvironment environment) {
  return GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return PlaceholderHomeScreen(environment: environment);
        },
      ),
    ],
  );
}

class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Text(
              environment.displayName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
      ),
    );
  }
}
