import 'dart:async';

enum ManualCleanupStage {
  repositoryDrain,
  stopLifecycleAndOutbox,
  purgeLocalData,
}

enum ManualCleanupFailureCode { scriptedFailure }

final class ManualCleanupException implements Exception {
  const ManualCleanupException(this.code);

  final ManualCleanupFailureCode code;

  @override
  String toString() => 'ManualCleanupException(${code.name})';
}

final class ManualCleanupControl {
  ManualCleanupControl._({required this.generation, required this.stage});

  final int generation;
  final ManualCleanupStage stage;
  final Completer<void> _started = Completer<void>();
  final Completer<void> _result = Completer<void>();
  var _timedOutObserved = false;

  Future<void> get started => _started.future;
  bool get isStarted => _started.isCompleted;
  bool get timedOutObserved => _timedOutObserved;
  bool get isCompleted => _result.isCompleted;

  Future<void> call() {
    if (!_started.isCompleted) _started.complete();
    return _result.future;
  }

  void succeed() {
    if (!_result.isCompleted) _result.complete();
  }

  void fail() {
    if (!_result.isCompleted) {
      _result.completeError(
        const ManualCleanupException(ManualCleanupFailureCode.scriptedFailure),
      );
    }
  }
}

final class ManualCleanupRun {
  ManualCleanupRun._(this._boundary, this.generation);

  final ManualChatCleanupBoundary _boundary;
  final int generation;
  final List<ManualCleanupControl> _controls = <ManualCleanupControl>[];

  ManualCleanupControl control(ManualCleanupStage stage) {
    final control = ManualCleanupControl._(
      generation: generation,
      stage: stage,
    );
    _controls.add(control);
    return control;
  }

  bool accepts(ManualCleanupControl control) =>
      _boundary.isCurrent(control) && _controls.contains(control);
}

/// Manual test clock substitute with no duration or production timeout.
final class ManualChatCleanupBoundary {
  var _generation = 0;

  ManualCleanupRun beginRun() => ManualCleanupRun._(this, ++_generation);

  void supersede() {
    _generation += 1;
  }

  bool isCurrent(ManualCleanupControl control) =>
      control.generation == _generation;

  bool observeTimedOut(ManualCleanupControl control) {
    control._timedOutObserved = true;
    return isCurrent(control);
  }
}
