import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mujoco/mujoco.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  test(
    'Compiled MuJoCo geom rotations preserve orientation in viewer space',
    () {
      final matrix = geomTransform([1, 2, 3], [0, -1, 0, 1, 0, 0, 0, 0, 1]);
      final p = matrix.transform3(vm.Vector3(1, 0, 0));
      expect(p, vm.Vector3(1, 3, 3));
      final expected = viewerPosition([p.x, p.y, p.z]);
      final actual = vm.Matrix4.rotationX(-math.pi / 2).transform3(p);
      expect((actual - expected).length, lessThan(1e-10));
    },
  );
  test('Viewer rejects mismatched model and data before allocating scene resources', () async {
    const xml =
        '<mujoco><worldbody><geom type="sphere" size=".1"/></worldbody></mujoco>';
    final first = compileXml(xml), second = compileXml(xml);
    final data = MjData(first);
    try {
      await expectLater(
        MujocoViewerController.create(model: second, data: data),
        throwsArgumentError,
      );
      expect(data.time, 0);
      expect(first.isDisposed, isFalse);
    } finally {
      data.dispose();
      first.dispose();
      second.dispose();
    }
  });
}

MjModel compileXml(String xml, {MjVfs? vfs}) {
  final spec = mj_parseXMLString(xml, vfs: vfs);
  try {
    return mj_compile(spec, vfs: vfs);
  } finally {
    spec.dispose();
  }
}
