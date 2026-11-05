/// Platform initialization for the pure Dart MuJoCo API.
library;

import 'src/initialize_native.dart'
    if (dart.library.js_interop) 'src/initialize_web.dart'
    as platform;

export 'package:mujoco/mujoco.dart';

abstract final class MujocoFlutter {
  static Future<void> initialize() => platform.initialize();
}
