final class ReconnectPolicy {
  const ReconnectPolicy({required this.randomUnit});

  final double Function() randomUnit;

  static const _baseDelays = <Duration>[
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 30),
  ];

  /// Returns the one-based reconnect delay with bounded ±20% jitter.
  ///
  /// Attempts after the sixth keep the 30 second base delay. Millisecond
  /// precision is retained because this scheduler is not persisted to the
  /// second-granularity Outbox schema.
  Duration delayForAttempt(int attempt) {
    if (attempt < 1) throw ArgumentError.value(attempt, 'attempt');
    final sample = randomUnit();
    if (!sample.isFinite || sample < 0 || sample > 1) {
      throw StateError('Invalid reconnect random sample');
    }
    final base = _baseDelays[(attempt - 1).clamp(0, _baseDelays.length - 1)];
    final multiplier = 0.8 + (sample * 0.4);
    return Duration(milliseconds: (base.inMilliseconds * multiplier).round());
  }
}
