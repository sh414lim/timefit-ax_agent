final RegExp _candidateUuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

final RegExp _candidateUtcTimestamp = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?Z$',
);

const int candidateJsonSafeIntegerMax = 9007199254740991;

bool isCandidateUuid(String value) => _candidateUuid.hasMatch(value);

bool isCandidateJsonSafeInteger(int value) =>
    value >= -candidateJsonSafeIntegerMax &&
    value <= candidateJsonSafeIntegerMax;

DateTime? parseCandidateUtcTimestamp(String value) {
  final match = _candidateUtcTimestamp.firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.parse(match.group(4)!);
  final minute = int.parse(match.group(5)!);
  final second = int.parse(match.group(6)!);
  final fraction = (match.group(7) ?? '').padRight(6, '0');
  final microsecond = fraction.isEmpty ? 0 : int.parse(fraction);
  final parsed = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    microsecond ~/ 1000,
    microsecond % 1000,
  );
  if (parsed.year != year ||
      parsed.month != month ||
      parsed.day != day ||
      parsed.hour != hour ||
      parsed.minute != minute ||
      parsed.second != second ||
      parsed.millisecond * 1000 + parsed.microsecond != microsecond) {
    return null;
  }
  return parsed;
}

Map<String, Object?>? candidateStringKeyedMap(Object? value) {
  if (value is! Map) return null;
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) return null;
    result[entry.key as String] = entry.value;
  }
  return result;
}
