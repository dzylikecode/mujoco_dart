import 'dart:convert';
import 'dart:typed_data';

import 'package:mujoco/mujoco.dart';
import 'package:test/test.dart';

import 'model_fixture.dart';

void main() {
  test('XML assets compile through VFS and produce geometry snapshots', () {
    final vfs = MjVfs();
    late final MjModel model;
    try {
      vfs.addBuffer(
        'tetra.obj',
        Uint8List.fromList(
          utf8.encode(
            'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\nf 1 3 2\nf 1 2 4\nf 1 4 3\nf 2 3 4\n',
          ),
        ),
      );
      model = compileXml(
        '<mujoco><asset><mesh name="tetra" file="tetra.obj"/></asset>'
        '<worldbody><geom name="visual" type="mesh" mesh="tetra"/></worldbody></mujoco>',
        vfs: vfs,
      );
    } finally {
      vfs.dispose();
    }
    final data = MjData(model);
    try {
      mj_forward(model, data);
      expect(model.ngeom, 1);
      expect(model.geomById(0).name, 'visual');
      expect(model.meshById(0).triangleCount, 4);
      expect(data.geomRotation(0).length, 9);
      final retained = data.geomPosition(0);
      data.dispose();
      expect(() => retained[0], throwsStateError);
      expect(() => data.qpos.toList(), throwsStateError);
      expect(() => MjData(model)..dispose(), returnsNormally);
    } finally {
      data.dispose();
      model.dispose();
    }
  });
  test('Physics rejects data owned by another model before native access', () {
    const xml =
        '<mujoco><worldbody><body><freejoint/><geom type="sphere" size="0.1"/></body></worldbody></mujoco>';
    final first = compileXml(xml), second = compileXml(xml);
    final data = MjData(first);
    try {
      expect(() => mj_step(second, data), throwsArgumentError);
      mj_step(first, data);
      expect(data.time, greaterThan(0));
      data.dispose();
      expect(() => mj_forward(first, data), throwsStateError);
    } finally {
      data.dispose();
      first.dispose();
      second.dispose();
    }
  });
}
