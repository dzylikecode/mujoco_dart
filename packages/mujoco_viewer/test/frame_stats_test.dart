import 'package:flutter_test/flutter_test.dart';
import 'package:mujoco_viewer/src/frame_stats.dart';

void main() {
  // 以实际渲染 tick 的时间间隔统计，而不是状态流的更新数量。
  test(
    'Frame statistics report measured cadence and the latest state time',
    () {
      final meter = ViewerFrameMeter();
      expect(meter.tick(Duration.zero, 0), isNull);
      for (var i = 1; i < 20; i++) {
        expect(meter.tick(Duration(milliseconds: i * 50), 12), isNull);
      }
      final stats = meter.tick(const Duration(seconds: 1), 12)!;
      expect(stats.fps, 20);
      expect(stats.averageFrameTime, const Duration(milliseconds: 50));
      expect(stats.frames, 20);
      expect(stats.stateTime, 12);
      // 仿真暂停后状态时间不变，渲染仍持续计数。
      for (var i = 21; i < 40; i++) {
        meter.tick(Duration(milliseconds: i * 50), 12);
      }
      expect(meter.tick(const Duration(seconds: 2), 12)!.fps, 20);
    },
  );

  test('Uneven frame intervals are averaged by elapsed time', () {
    final meter = ViewerFrameMeter();
    meter.tick(Duration.zero, 0);
    meter.tick(const Duration(milliseconds: 100), 1);
    meter.tick(const Duration(milliseconds: 250), 2);
    final stats = meter.tick(const Duration(milliseconds: 1200), 3)!;
    expect(stats.fps, 2.5);
    expect(stats.averageFrameTime, const Duration(milliseconds: 400));
  });

  test(
    'Reset and restarted timelines discard previous measurement windows',
    () {
      final meter = ViewerFrameMeter();
      meter.tick(Duration.zero, 0);
      meter.tick(const Duration(milliseconds: 900), 0);
      meter.reset();
      expect(meter.tick(const Duration(seconds: 50), 0), isNull);
      expect(meter.tick(const Duration(milliseconds: 50100), 0), isNull);
      expect(meter.tick(Duration.zero, 0), isNull);
      expect(meter.tick(const Duration(milliseconds: 900), 0), isNull);
      expect(meter.tick(const Duration(seconds: 1), 0)!.frames, 2);
    },
  );
}
