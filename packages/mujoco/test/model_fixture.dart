import 'package:mujoco/mujoco.dart';

MjModel compileXml(String xml, {MjVfs? vfs}) {
  final spec = mj_parseXMLString(xml, vfs: vfs);
  try {
    return mj_compile(spec, vfs: vfs);
  } finally {
    spec.dispose();
  }
}
