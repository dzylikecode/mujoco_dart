import 'package:flutter/services.dart';
import 'package:mujoco/mujoco.dart';

Future<MjModel> loadBundledDemo() async {
  final vfs = MjVfs();
  try {
    final bytes = await rootBundle.load('assets/physics_lab.xml');
    vfs.addBuffer(
      'physics_lab.xml',
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    return mj_loadXML('physics_lab.xml', vfs: vfs);
  } finally {
    vfs.dispose();
  }
}
