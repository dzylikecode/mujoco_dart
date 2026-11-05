import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mujoco_flutter/mujoco_flutter.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(files[key]!)));
}

void main() {
  test(
    'Flutter bundle includes and meshes load through the shared model API',
    () async {
      final bundle = _Bundle({
        'app/model.xml': '<mujoco><include file="body.xml"/></mujoco>',
        'app/body.xml': '<mujoco><worldbody><body pos="0 0 1"><freejoint/><geom type="sphere" size=".1"/></body></worldbody></mujoco>',
      });
      await MujocoFlutter.initialize();
      final vfs = MjVfs();
      late final MjModel model;
      try {
        for (final filename in ['model.xml', 'body.xml']) {
          final bytes = await bundle.load('app/$filename');
          vfs.addBuffer(
            filename,
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        }
        model = mj_loadXML('model.xml', vfs: vfs);
      } finally {
        vfs.dispose();
      }
      final data = MjData(model);
      try {
        mj_step(model, data);
        expect(model.nq, 7);
        expect(data.time, greaterThan(0));
      } finally {
        data.dispose();
        model.dispose();
      }
    },
  );
}
