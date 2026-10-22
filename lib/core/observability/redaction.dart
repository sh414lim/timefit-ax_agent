import 'dart:collection';

const String redactedValue = '[REDACTED]';

const Set<String> _allowedFieldNames = {
  'ageMs',
  'attachmentId',
  'attempt',
  'clientMessageId',
  'count',
  'errorCode',
  'eventId',
  'latencyMs',
  'stage',
};

/// Raw strings never implement this type and are redacted by default.
sealed class SafeLogValue {
  const SafeLogValue();
  Object toJsonValue();
}

final class SafeLogText extends SafeLogValue {
  SafeLogText._(this.value);
  final String value;

  static SafeLogText stableCode(String value) => SafeLogText._(
    _validate(value, 'stable code', RegExp(r'^[a-z][a-z0-9_]{0,63}$')),
  );

  static SafeLogText environment(String value) => SafeLogText._(
    _validate(
      value,
      'environment',
      RegExp(r'^(local|test|staging|production)$'),
    ),
  );

  static SafeLogText buildValue(String value) => SafeLogText._(
    _validate(
      value,
      'build value',
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$'),
    ),
  );

  @override
  Object toJsonValue() => value;
}

sealed class CorrelationId extends SafeLogValue {
  CorrelationId(String value) : value = _validateCorrelationId(value);
  final String value;
  @override
  Object toJsonValue() => value;
}

final class ClientMessageId extends CorrelationId {
  ClientMessageId(super.value);
}

final class AttachmentId extends CorrelationId {
  AttachmentId(super.value);
}

final class EventId extends CorrelationId {
  EventId(super.value);
}

final class SafeLogNumber extends SafeLogValue {
  const SafeLogNumber(this.value);
  final num value;
  @override
  Object toJsonValue() => value;
}

final class SafeLogFlag extends SafeLogValue {
  const SafeLogFlag(this.value);
  final bool value;
  @override
  Object toJsonValue() => value;
}

String _validate(String value, String name, RegExp pattern) {
  if (!pattern.hasMatch(value)) throw ArgumentError.value(value, name);
  return value;
}

String _validateCorrelationId(String value) => _validate(
  value,
  'correlation id',
  RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'),
);

/// Recursively converts data to an export-safe structure. Unknown keys are
/// dropped and unknown values are never stringified. Cycles and excessive
/// depth collapse to [REDACTED].
Object? redactForExport(Object? value) {
  try {
    return _redact(value, HashSet<Object>.identity(), 0);
  } on Object {
    return redactedValue;
  }
}

Object? _redact(Object? value, Set<Object> seen, int depth) {
  if (value == null) return null;
  if (value is SafeLogValue) return value.toJsonValue();
  if (depth >= 6) return redactedValue;
  if (value is Map<Object?, Object?>) {
    if (!seen.add(value)) return redactedValue;
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String && _allowedFieldNames.contains(key)) {
        result[key] = _redact(entry.value, seen, depth + 1);
      }
    }
    seen.remove(value);
    return result;
  }
  if (value is Iterable<Object?>) {
    if (!seen.add(value)) return redactedValue;
    final result = <Object?>[];
    for (final item in value.take(32)) {
      result.add(_redact(item, seen, depth + 1));
    }
    seen.remove(value);
    return result;
  }
  return redactedValue;
}
