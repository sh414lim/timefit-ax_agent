final class RetryPolicy {
  const RetryPolicy(this.randomUnit);
  final double Function() randomUnit;
  static const maximumFailures = 8;

  Duration delay(int failures) {
    if (failures < 1) throw ArgumentError.value(failures);
    final unit = randomUnit();
    if (unit < 0 || unit > 1 || !unit.isFinite)
      throw StateError('Invalid random sample');
    const seconds = [1, 2, 4, 8, 16, 30];
    final base = seconds[(failures - 1).clamp(0, seconds.length - 1)];
    // Schema v1 stores timestamps in seconds: keep sampled jitter in its
    // representable range instead of losing sub-second delay on persistence.
    final minimum = (base * 0.8).ceil();
    final maximum = (base * 1.2).floor();
    final jittered = (base * (0.8 + unit * 0.4)).round().clamp(
      minimum,
      maximum,
    );
    return Duration(seconds: jittered);
  }
}
