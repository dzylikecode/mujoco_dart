import 'package:mujoco/mujoco.dart';

MjModel loadLocalModel(String path) => throw UnsupportedError(
  'Browser cannot read local paths; use bundled assets or XML with asset bytes.',
);
String modelLabel(String path) => path;
