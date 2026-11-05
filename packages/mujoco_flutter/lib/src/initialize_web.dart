import 'package:mujoco/js.dart';
import 'package:mujoco_web/browser.dart';

Future<void> initialize() async =>
    initializeMujocoJs(await MujocoWeb.initialize());
