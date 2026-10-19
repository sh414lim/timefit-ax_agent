import 'package:flutter/material.dart';

import '../src/app_environment.dart';
import 'app.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';

typedef TimeFitAppRunner = void Function(Widget app);

void runTimeFitApp(
  AppEnvironment environment, {
  TimeFitAppRunner appRunner = runApp,
}) {
  void retry() => runTimeFitApp(environment, appRunner: appRunner);

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: BootstrapFailureScreen(onRetry: retry),
    );
  };
  appRunner(
    TimeFitErrorBoundary(
      onRetry: retry,
      child: TimeFitApp(key: UniqueKey(), environment: environment),
    ),
  );
}

class TimeFitErrorBoundary extends StatelessWidget {
  const TimeFitErrorBoundary({
    required this.child,
    required this.onRetry,
    this.failure,
    super.key,
  });

  final Widget child;
  final VoidCallback onRetry;
  final Object? failure;

  @override
  Widget build(BuildContext context) {
    if (failure != null) {
      return BootstrapFailureScreen(onRetry: onRetry);
    }
    return child;
  }
}

class BootstrapFailureScreen extends StatelessWidget {
  const BootstrapFailureScreen({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.x24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.x48,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          '앱을 시작하지 못했습니다',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.x12),
                        Text(
                          '네트워크 상태를 확인한 뒤 잠시 후 다시 시도해 주세요.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.x24),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppTouchTarget.minimum,
                            minWidth: AppTouchTarget.minimum * 3,
                          ),
                          child: FilledButton(
                            onPressed: onRetry,
                            child: const Text('다시 시도'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
