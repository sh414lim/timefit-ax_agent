enum AppEnvironment {
  dev(
    displayName: 'TimeFit Dev',
    configurationKey: 'dev',
    expectedEntrypoint: 'lib/main.dart',
    isRunnable: true,
  ),
  staging(
    displayName: 'TimeFit Staging',
    configurationKey: 'staging',
    expectedEntrypoint: 'lib/main_staging.dart',
    isRunnable: true,
  ),
  production(
    displayName: 'TimeFit',
    configurationKey: null,
    expectedEntrypoint: null,
    isRunnable: false,
  );

  const AppEnvironment({
    required this.displayName,
    required this.configurationKey,
    required this.expectedEntrypoint,
    required this.isRunnable,
  });

  final String displayName;
  final String? configurationKey;
  final String? expectedEntrypoint;
  final bool isRunnable;
}
