// The platform adapter intentionally uses mujoco's internal registration hook.
// These packages are maintained together in this workspace.
// ignore: implementation_imports
import 'package:mujoco/src/web_initialization.dart';
import 'package:mujoco_web/browser.dart';

Future<void> initialize() async {
  final module = await MujocoWeb.initialize();
  // ignore: invalid_use_of_internal_member
  initializeMujocoJs(module);
}
