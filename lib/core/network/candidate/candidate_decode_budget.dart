import 'dart:collection';
import 'dart:convert';

/// Local defensive limits for the unapproved CHAT-032 candidate decoders.
///
/// These values are not server limits and must not be treated as an approved
/// wire contract. They only bound local parsing until CHAT-001/030 approve the
/// real envelope and field limits.
final class CandidateDecodeBudget {
  const CandidateDecodeBudget({
    this.maxUtf8Bytes = 1000000,
    this.maxDepth = 32,
    this.maxContainerEntries = 256,
    this.maxTotalNodes = 4096,
  }) : assert(maxUtf8Bytes > 0),
       assert(maxDepth >= 0),
       assert(maxContainerEntries > 0),
       assert(maxTotalNodes > 0);

  final int maxUtf8Bytes;
  final int maxDepth;
  final int maxContainerEntries;
  final int maxTotalNodes;
}

sealed class CandidateBoundedDecodeResult {
  const CandidateBoundedDecodeResult();
}

final class CandidateBoundedValue extends CandidateBoundedDecodeResult {
  const CandidateBoundedValue(this.value);

  /// A detached tree containing only standard JSON-compatible values.
  final Object? value;
}

final class CandidateBudgetRejected extends CandidateBoundedDecodeResult {
  const CandidateBudgetRejected();
}

final class CandidateInputInvalid extends CandidateBoundedDecodeResult {
  const CandidateInputInvalid();
}

/// Decodes and detaches candidate JSON without exposing parser exceptions.
///
/// String input is rejected by UTF-8 byte and lexical nesting limits before
/// `jsonDecode`. Parsed input is walked with the same structural limits. The
/// detached result prevents a hostile/custom Map from changing or throwing on
/// a later validation pass.
CandidateBoundedDecodeResult decodeCandidateJsonWithinBudget(
  Object? input, {
  CandidateDecodeBudget budget = const CandidateDecodeBudget(),
}) {
  try {
    Object? decoded = input;
    if (input is String) {
      switch (_checkJsonText(input, budget)) {
        case _CandidateTextCheck.budgetExceeded:
          return const CandidateBudgetRejected();
        case _CandidateTextCheck.invalid:
          return const CandidateInputInvalid();
        case _CandidateTextCheck.ok:
          break;
      }
      try {
        decoded = jsonDecode(input);
      } on Object {
        return const CandidateInputInvalid();
      }
    }
    final walker = _CandidateBudgetWalker(budget);
    return CandidateBoundedValue(walker.detach(decoded));
  } on _CandidateBudgetExceeded {
    return const CandidateBudgetRejected();
  } on Object {
    return const CandidateInputInvalid();
  }
}

_CandidateTextCheck _checkJsonText(
  String source,
  CandidateDecodeBudget budget,
) {
  // Escapes and insignificant JSON formatting do not exist in an already
  // parsed object. A separate bounded 8x source ceiling protects jsonDecode,
  // while maxUtf8Bytes itself is enforced on the detached logical tree so the
  // string and object paths make the same decision.
  final rawJsonCeiling = budget.maxUtf8Bytes * 8;
  var utf8Bytes = 0;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = 0; index < source.length; index += 1) {
    final codeUnit = source.codeUnitAt(index);
    if (codeUnit <= 0x7f) {
      utf8Bytes += 1;
    } else if (codeUnit <= 0x7ff) {
      utf8Bytes += 2;
    } else if (codeUnit >= 0xd800 &&
        codeUnit <= 0xdbff &&
        index + 1 < source.length &&
        source.codeUnitAt(index + 1) >= 0xdc00 &&
        source.codeUnitAt(index + 1) <= 0xdfff) {
      utf8Bytes += 4;
      index += 1;
    } else {
      utf8Bytes += 3;
    }
    if (utf8Bytes > rawJsonCeiling) {
      return _CandidateTextCheck.budgetExceeded;
    }

    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (codeUnit == 0x5c) {
        escaped = true;
      } else if (codeUnit == 0x22) {
        inString = false;
      }
      continue;
    }
    if (codeUnit == 0x22) {
      inString = true;
    } else if (codeUnit == 0x7b || codeUnit == 0x5b) {
      depth += 1;
      if (depth > budget.maxDepth) {
        return _CandidateTextCheck.budgetExceeded;
      }
    } else if (codeUnit == 0x7d || codeUnit == 0x5d) {
      depth -= 1;
      if (depth < 0) return _CandidateTextCheck.invalid;
    }
  }
  return depth == 0 && !inString && !escaped
      ? _CandidateTextCheck.ok
      : _CandidateTextCheck.invalid;
}

enum _CandidateTextCheck { ok, budgetExceeded, invalid }

final class _CandidateBudgetWalker {
  _CandidateBudgetWalker(this.budget);

  final CandidateDecodeBudget budget;
  final Set<Object> _activeContainers = HashSet<Object>.identity();
  var _nodes = 0;
  var _estimatedUtf8Bytes = 0;

  Object? detach(Object? value, [int containingDepth = 0]) {
    _countNode();
    if (value == null) {
      _countBytes(4);
      return null;
    }
    if (value is bool) {
      _countBytes(value ? 4 : 5);
      return value;
    }
    if (value is int) {
      _countBytes(24);
      return value;
    }
    if (value is double) {
      if (!value.isFinite) throw const _CandidateInputInvalidException();
      _countBytes(24);
      return value;
    }
    if (value is String) {
      _countString(value);
      return value;
    }
    if (value is List) return _detachList(value, containingDepth + 1);
    if (value is Map) return _detachMap(value, containingDepth + 1);
    throw const _CandidateInputInvalidException();
  }

  List<Object?> _detachList(List<dynamic> value, int containerDepth) {
    if (containerDepth > budget.maxDepth) {
      throw const _CandidateBudgetExceeded();
    }
    if (!_activeContainers.add(value)) {
      throw const _CandidateBudgetExceeded();
    }
    try {
      final length = value.length;
      if (length > budget.maxContainerEntries) {
        throw const _CandidateBudgetExceeded();
      }
      _countBytes(2 + length);
      return List<Object?>.unmodifiable(<Object?>[
        for (var index = 0; index < length; index += 1)
          detach(value[index], containerDepth),
      ]);
    } finally {
      _activeContainers.remove(value);
    }
  }

  Map<String, Object?> _detachMap(
    Map<dynamic, dynamic> value,
    int containerDepth,
  ) {
    if (containerDepth > budget.maxDepth) {
      throw const _CandidateBudgetExceeded();
    }
    if (!_activeContainers.add(value)) {
      throw const _CandidateBudgetExceeded();
    }
    try {
      final output = <String, Object?>{};
      final iterator = value.entries.iterator;
      var entryCount = 0;
      while (iterator.moveNext()) {
        entryCount += 1;
        if (entryCount > budget.maxContainerEntries) {
          throw const _CandidateBudgetExceeded();
        }
        final entry = iterator.current;
        final key = entry.key;
        if (key is! String || output.containsKey(key)) {
          throw const _CandidateInputInvalidException();
        }
        _countNode();
        _countString(key);
        output[key] = detach(entry.value, containerDepth);
      }
      _countBytes(2 + entryCount);
      return Map<String, Object?>.unmodifiable(output);
    } finally {
      _activeContainers.remove(value);
    }
  }

  void _countNode() {
    _nodes += 1;
    if (_nodes > budget.maxTotalNodes) {
      throw const _CandidateBudgetExceeded();
    }
  }

  void _countString(String value) {
    _countBytes(2);
    for (final rune in value.runes) {
      _countBytes(
        rune <= 0x7f
            ? 1
            : rune <= 0x7ff
            ? 2
            : rune <= 0xffff
            ? 3
            : 4,
      );
    }
  }

  void _countBytes(int count) {
    _estimatedUtf8Bytes += count;
    if (_estimatedUtf8Bytes > budget.maxUtf8Bytes) {
      throw const _CandidateBudgetExceeded();
    }
  }
}

final class _CandidateBudgetExceeded implements Exception {
  const _CandidateBudgetExceeded();
}

final class _CandidateInputInvalidException implements Exception {
  const _CandidateInputInvalidException();
}
