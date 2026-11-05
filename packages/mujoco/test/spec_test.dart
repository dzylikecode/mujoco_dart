import 'dart:convert';
import 'dart:typed_data';

import 'package:mujoco/mujoco.dart';
import 'package:test/test.dart';

void main() {
  test('A spec compiles repeatedly and models outlive it', () {
    final spec = mj_parseXMLString(
      '''<mujoco><worldbody><body>
      <freejoint/><geom type="sphere" size=".1"/></body></worldbody></mujoco>''',
    );
    final models = <MjModel>[];
    try {
      models.add(mj_compile(spec));
      models.add(mj_compile(spec));
      expect(spec.isDisposed, isFalse);
      spec.dispose();
      spec.dispose();
      expect(spec.isDisposed, isTrue);
      for (final model in models) {
        final data = MjData(model);
        try {
          mj_step(model, data);
          expect(data.time, greaterThan(0));
        } finally {
          data.dispose();
        }
      }
      expect(() => mj_compile(spec), throwsStateError);
    } finally {
      spec.dispose();
      for (final model in models) {
        model.dispose();
      }
    }
  });

  test(
    'Parse and compile failures are separate and keep caller resources alive',
    () {
      expect(() => mj_parseXMLString('<invalid>'), throwsFormatException);
      final spec = mj_parseXMLString(
        '''<mujoco><asset><mesh name="mesh" file="tetra.obj"/></asset>
      <worldbody><geom type="mesh" mesh="mesh"/></worldbody></mujoco>''',
      );
      final vfs = MjVfs();
      try {
        expect(() => mj_compile(spec, vfs: vfs), throwsFormatException);
        expect(spec.isDisposed, isFalse);
        expect(vfs.isDisposed, isFalse);
        vfs.addBuffer(
          'tetra.obj',
          Uint8List.fromList(
            utf8.encode(
              'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\nf 1 3 2\nf 1 2 4\nf 1 4 3\nf 2 3 4\n',
            ),
          ),
        );
        final model = mj_compile(spec, vfs: vfs);
        try {
          expect(model.meshById(0).triangleCount, 4);
        } finally {
          model.dispose();
        }
      } finally {
        spec.dispose();
        vfs.dispose();
      }
    },
  );

  test('Every compilation entry rejects disposed resources', () {
    final spec = mj_parseXMLString('<mujoco/>');
    final vfs = MjVfs()..dispose();
    try {
      expect(() => mj_compile(spec, vfs: vfs), throwsStateError);
      expect(() => mj_parseXMLString('<mujoco/>', vfs: vfs), throwsStateError);
      expect(() => mj_loadXML('robot.xml', vfs: vfs), throwsStateError);
    } finally {
      spec.dispose();
    }
  });
}
