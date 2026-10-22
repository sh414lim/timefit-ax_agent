import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart';

int rawEngineFrameTimestampMicros(SchedulerBinding binding) {
  return binding.currentSystemFrameTimeStamp.inMicroseconds;
}

class PerformanceFrameSample {
  const PerformanceFrameSample({
    required this.buildMicros,
    required this.rasterMicros,
    required this.totalMicros,
    required this.vsyncStartMicros,
    required this.buildStartMicros,
    required this.rasterFinishMicros,
  });

  factory PerformanceFrameSample.fromTiming(FrameTiming timing) {
    return PerformanceFrameSample(
      buildMicros: timing.buildDuration.inMicroseconds,
      rasterMicros: timing.rasterDuration.inMicroseconds,
      totalMicros: timing.totalSpan.inMicroseconds,
      vsyncStartMicros: timing.timestampInMicroseconds(FramePhase.vsyncStart),
      buildStartMicros: timing.timestampInMicroseconds(FramePhase.buildStart),
      rasterFinishMicros: timing.timestampInMicroseconds(
        FramePhase.rasterFinish,
      ),
    );
  }

  final int buildMicros;
  final int rasterMicros;
  final int totalMicros;
  final int vsyncStartMicros;
  final int buildStartMicros;
  final int rasterFinishMicros;

  Map<String, int> toJson() => <String, int>{
    'buildMicros': buildMicros,
    'rasterMicros': rasterMicros,
    'totalMicros': totalMicros,
    'vsyncStartMicros': vsyncStartMicros,
    'buildStartMicros': buildStartMicros,
    'rasterFinishMicros': rasterFinishMicros,
  };
}

List<PerformanceFrameSample> selectFramesInsideEngineWindow({
  required Iterable<PerformanceFrameSample> samples,
  required int startExclusiveMicros,
  required int endExclusiveMicros,
}) {
  if (endExclusiveMicros <= startExclusiveMicros) {
    throw ArgumentError('invalid_engine_frame_window');
  }
  return samples
      .where(
        (sample) =>
            sample.vsyncStartMicros > startExclusiveMicros &&
            sample.rasterFinishMicros < endExclusiveMicros,
      )
      .toList(growable: false);
}
