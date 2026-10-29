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

final class ErrorCode extends SafeLogValue {
  ErrorCode(String value)
    : value = _validate(value, 'error code', RegExp(r'^[a-z][a-z0-9_]{0,63}$'));

  final String value;

  @override
  Object toJsonValue() => value;
}

final class EventCode extends SafeLogValue {
  EventCode(String value)
    : value = _validate(value, 'event code', RegExp(r'^[a-z][a-z0-9_]{0,63}$'));

  final String value;

  @override
  Object toJsonValue() => value;
}

enum UploadStageValue implements SafeLogValue {
  queued,
  copying,
  uploading,
  ready,
  failed;

  @override
  Object toJsonValue() => name;
}

sealed class CorrelationId extends SafeLogValue {
  CorrelationId(String value) : value = _validateCorrelationId(value);
  final String value;
  @override
  Object toJsonValue() => value;
}

final class ClientMessageId extends CorrelationId {
  ClientMessageId(super.value);

  static ClientMessageId? tryForExport(String value) {
    try {
      final id = ClientMessageId(value);
      return _isTypedIdValue(id.value, 'message') ? id : null;
    } on Object {
      return null;
    }
  }
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
  Object toJsonValue() => value.isFinite ? value : redactedValue;
}

final class SafeLogFlag extends SafeLogValue {
  const SafeLogFlag(this.value);
  final bool value;
  @override
  Object toJsonValue() => value;
}

String _validate(String value, String name, RegExp pattern) {
  if (!pattern.hasMatch(value)) throw ArgumentError('Invalid $name');
  return value;
}

String _validateCorrelationId(String value) => _validate(
  value,
  'correlation id',
  RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$'),
);

bool _isTypedIdValue(String value, String testPrefix) => RegExp(
  '^(?:$testPrefix-[0-9]+|'
  r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
  r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12})$',
).hasMatch(value);

/// Recursively converts data to an export-safe structure. Unknown keys are
/// dropped and unknown values are never stringified. Cycles and excessive
/// depth collapse to [REDACTED].
Object? redactForExport(Object? value) {
  try {
    return _redact(value, HashSet<Object>.identity(), _RedactionBudget(256), 0);
  } on Object {
    return redactedValue;
  }
}

Object? _redact(
  Object? value,
  Set<Object> seen,
  _RedactionBudget budget,
  int depth,
) {
  if (!budget.consume()) return redactedValue;
  if (value == null) return null;
  if (value is SafeLogValue) return value.toJsonValue();
  if (depth >= 6) return redactedValue;
  if (value is Map<Object?, Object?>) {
    if (!seen.add(value)) return redactedValue;
    final result = <String, Object?>{};
    final iterator = value.entries.iterator;
    var entries = 0;
    while (entries < 64 && budget.consume() && iterator.moveNext()) {
      entries += 1;
      final entry = iterator.current;
      final key = entry.key;
      if (key is String && _allowedFieldNames.contains(key)) {
        result[key] = _redactField(key, entry.value, seen, budget, depth + 1);
      }
    }
    return result;
  }
  if (value is Iterable<Object?>) {
    if (!seen.add(value)) return redactedValue;
    final result = <Object?>[];
    final iterator = value.iterator;
    var items = 0;
    while (items < 32 && budget.consume() && iterator.moveNext()) {
      items += 1;
      result.add(_redact(iterator.current, seen, budget, depth + 1));
    }
    return result;
  }
  return redactedValue;
}

Object? _redactField(
  String key,
  Object? value,
  Set<Object> seen,
  _RedactionBudget budget,
  int depth,
) {
  final valid = switch (key) {
    'clientMessageId' =>
      value is ClientMessageId && _isTypedIdValue(value.value, 'message'),
    'attachmentId' =>
      value is AttachmentId && _isTypedIdValue(value.value, 'attachment'),
    'eventId' => value is EventId && _isTypedIdValue(value.value, 'event'),
    'errorCode' => value is ErrorCode,
    'stage' => value is UploadStageValue,
    'ageMs' || 'attempt' || 'count' || 'latencyMs' => value is SafeLogNumber,
    _ => false,
  };
  return valid ? _redact(value, seen, budget, depth) : redactedValue;
}

final class _RedactionBudget {
  _RedactionBudget(this._remaining);
  int _remaining;

  bool consume() {
    if (_remaining <= 0) return false;
    _remaining -= 1;
    return true;
  }
}
