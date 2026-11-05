import 'package:mujoco/mujoco.dart';
import 'package:path/path.dart' as p;

MjModel loadLocalModel(String path) => mj_loadXML(p.absolute(path));
String modelLabel(String path) => p.basename(path);
