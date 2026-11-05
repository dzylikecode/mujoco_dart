import 'dart:typed_data';

import 'package:mujoco/mujoco.dart';
import 'package:test/test.dart';

void main() {
  // 快照拥有自己的内存，原数据变化与释放都不影响已发布状态。
  test(
    'Scene snapshots remain immutable after stepping and disposing data',
    () {
      final model = MjModel.from_xml_string('''<mujoco><worldbody>
      <body pos="0 0 2"><freejoint/><geom type="sphere" size=".1"/></body>
    </worldbody></mujoco>''');
      final data = MjData(model);
      mj_forward(model, data);
      final first = MjSceneState.fromData(data);
      data.qpos[2] = 5;
      mj_forward(model, data);
      final second = MjSceneState.fromData(data);
      data.dispose();
      model.dispose();
      expect(first.geomCount, 1);
      expect(first.positions, [0, 0, 2]);
      expect(second.positions, [0, 0, 5]);
      expect(first.rotations, [1, 0, 0, 0, 1, 0, 0, 0, 1]);
      expect(() => first.positions[0] = 9, throwsUnsupportedError);
      expect(() => first.rotations[0] = 9, throwsUnsupportedError);
    },
  );

  test(
    'Scene state construction copies caller buffers and validates layout',
    () {
      final positions = Float64List.fromList([1, 2, 3]);
      final state = MjSceneState(
        time: 2,
        positions: positions,
        rotations: [1, 0, 0, 0, 1, 0, 0, 0, 1],
      );
      positions[0] = 99;
      expect(state.positions[0], 1);
      expect(state.time, 2);
      expect(
        () => MjSceneState(time: 0, positions: [1], rotations: []),
        throwsArgumentError,
      );
      expect(
        () => MjSceneState(time: 0, positions: [1, 2, 3], rotations: []),
        throwsArgumentError,
      );
      expect(
        () => MjSceneState(time: double.nan, positions: [], rotations: []),
        throwsArgumentError,
      );
    },
  );
}
