import 'dart:convert';
import 'dart:typed_data';

import 'package:mujoco/mujoco.dart';
import 'package:test/test.dart';

import 'model_fixture.dart';

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

const xml = '<mujoco><include file="body.xml"/></mujoco>';
const body =
    '''<mujoco><asset><mesh name="tetra" file="meshes/tetra.obj"/></asset>
<worldbody><body pos="0 0 1"><freejoint/>
<geom type="mesh" mesh="tetra" mass="1"/></body></worldbody></mujoco>''';
const mesh =
    'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\nf 1 3 2\nf 1 2 4\nf 1 4 3\nf 2 3 4\n';

void main() {
  test('VFS copies files, resolves includes and meshes, and is reusable', () {
    final vfs = MjVfs();
    final models = <MjModel>[];
    try {
      final source = bytes(xml);
      vfs.addBuffer('robot.xml', source);
      source.fillRange(0, source.length, 0);
      vfs.addBuffer('body.xml', bytes(body));
      vfs.addBuffer('meshes/tetra.obj', bytes(mesh));
      models.add(mj_loadXML('robot.xml', vfs: vfs));
      models.add(compileXml(xml, vfs: vfs));
      expect(vfs.isDisposed, isFalse);
      vfs.dispose();
      vfs.dispose();
      expect(vfs.isDisposed, isTrue);
      for (final model in models) {
        final data = MjData(model);
        try {
          expect(model.nmesh, 1);
          expect(model.meshById(0).triangleCount, 4);
          mj_step(model, data);
          expect(data.time, greaterThan(0));
        } finally {
          data.dispose();
        }
      }
    } finally {
      vfs.dispose();
      for (final model in models) {
        model.dispose();
      }
    }
  });

  test('Files can be deleted and replaced after failed compilation', () {
    final vfs = MjVfs();
    try {
      vfs.addBuffer('robot.xml', bytes('<invalid>'));
      expect(() => mj_loadXML('robot.xml', vfs: vfs), throwsFormatException);
      expect(() => vfs.addBuffer('robot.xml', bytes(xml)), throwsStateError);
      vfs.deleteFile('robot.xml');
      expect(() => vfs.deleteFile('robot.xml'), returnsNormally);
      vfs.addBuffer('robot.xml', bytes('<mujoco/>'));
      final model = mj_loadXML('robot.xml', vfs: vfs);
      model.dispose();
      expect(vfs.isDisposed, isFalse);
    } finally {
      vfs.dispose();
    }
  });

  test('Disposed VFS is rejected before loading', () {
    final vfs = MjVfs();
    try {
      expect(() => vfs.addBuffer('', bytes(xml)), throwsArgumentError);
      expect(
        () => vfs.addBuffer('bad\u0000.xml', bytes(xml)),
        throwsArgumentError,
      );
      vfs.dispose();
      expect(() => vfs.addBuffer('robot.xml', bytes(xml)), throwsStateError);
      expect(() => vfs.deleteFile('robot.xml'), throwsStateError);
      expect(() => mj_loadXML('robot.xml', vfs: vfs), throwsStateError);
      expect(() => compileXml(xml, vfs: vfs), throwsStateError);
    } finally {
      vfs.dispose();
    }
  });
}
