import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as scene;

import 'controller.dart';

/// Renders caller-owned MuJoCo state. Never advances physics on its own.
/// Dispose the controller after unmounting this widget; then dispose data/model.
class MujocoViewer extends StatelessWidget {
  const MujocoViewer({super.key, required this.controller, this.onTick});
  final MujocoViewerController controller;
  final void Function(Duration elapsed, double deltaSeconds)? onTick;
  @override
  Widget build(BuildContext context) => scene.CameraControls(
    controller: controller.orbit,
    child: scene.SceneView(
      controller.world,
      onTick: (elapsed, dt) {
        onTick?.call(elapsed, dt);
        controller.sync();
      },
    ),
  );
}
