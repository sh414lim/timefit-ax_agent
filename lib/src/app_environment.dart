enum AppEnvironment {
  dev(displayName: 'TimeFit Dev', configurationKey: 'dev', isRunnable: true),
  staging(
    displayName: 'TimeFit Staging',
    configurationKey: 'staging',
    isRunnable: true,
  ),
  production(displayName: 'TimeFit', configurationKey: null, isRunnable: false);

  const AppEnvironment({
    required this.displayName,
    required this.configurationKey,
    required this.isRunnable,
  });

  final String displayName;
  final String? configurationKey;
  final bool isRunnable;
}
