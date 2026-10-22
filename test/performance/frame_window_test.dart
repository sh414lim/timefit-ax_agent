import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/frame_window.dart';

void main() {
  const before = PerformanceFrameSample(
    buildMicros: 1,
    rasterMicros: 1,
    totalMicros: 2,
    vsyncStartMicros: 80,
    buildStartMicros: 81,
    rasterFinishMicros: 90,
  );
  const inside = PerformanceFrameSample(
    buildMicros: 3,
    rasterMicros: 4,
    totalMicros: 10,
    vsyncStartMicros: 110,
    buildStartMicros: 112,
    rasterFinishMicros: 120,
  );
  const crossingEnd = PerformanceFrameSample(
    buildMicros: 2,
    rasterMicros: 3,
    totalMicros: 8,
    vsyncStartMicros: 195,
    buildStartMicros: 196,
    rasterFinishMicros: 203,
  );
  const delayedOutside = PerformanceFrameSample(
    buildMicros: 1,
    rasterMicros: 1,
    totalMicros: 2,
    vsyncStartMicros: 210,
    buildStartMicros: 211,
    rasterFinishMicros: 220,
  );

  test('keeps only frames wholly inside engine-clock action markers', () {
    final selected = selectFramesInsideEngineWindow(
      samples: const <PerformanceFrameSample>[
        before,
        inside,
        crossingEnd,
        delayedOutside,
      ],
      startExclusiveMicros: 100,
      endExclusiveMicros: 200,
    );

    expect(selected, <PerformanceFrameSample>[inside]);
  });

  test('late callback delivery does not admit post-action timestamps', () {
    final deliveredLate = selectFramesInsideEngineWindow(
      samples: const <PerformanceFrameSample>[inside, delayedOutside],
      startExclusiveMicros: 100,
      endExclusiveMicros: 200,
    );

    expect(deliveredLate, <PerformanceFrameSample>[inside]);
  });

  test('invalid or missing marker ordering fails closed', () {
    expect(
      () => selectFramesInsideEngineWindow(
        samples: const <PerformanceFrameSample>[inside],
        startExclusiveMicros: 200,
        endExclusiveMicros: 200,
      ),
      throwsArgumentError,
    );
  });
}
