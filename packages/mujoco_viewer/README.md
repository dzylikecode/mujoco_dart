# mujoco_viewer

A Flutter visualization package built on Flutter Scene, using the public MuJoCo model/data API on native and web. The former Python `launch_passive` viewer and Python dependencies have been removed.

```dart
import 'package:mujoco_flutter/mujoco_flutter.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';

await MujocoFlutter.initialize();
// Prepare a VFS containing robot.xml and its referenced assets.
final model = MjModel.from_xml_path('robot.xml', vfs: vfs);
final data = MjData(model);
mj_forward(model, data);
final controller = await MujocoViewerController.create(model: model, data: data);
// Place inside bounded Flutter layout constraints:
final widget = MujocoViewer(controller: controller);
```

The widget is passive: it displays caller-owned state and synchronizes geom poses each frame. The application owns the physics loop. For example, advance the same model/data above at a fixed timestep:

```dart
double accumulator = 0;
final widget = MujocoViewer(
  controller: controller,
  onTick: (_, dt) {
    accumulator += dt.clamp(0.0, 0.05);
    while (accumulator >= model.timestep) {
      mj_step(model, data);
      accumulator -= model.timestep;
    }
    mj_forward(model, data);
  },
);
```

Unmount the widget, dispose its controller, then dispose caller-owned data and model. The controller never disposes physics resources. It validates that data belongs to the supplied model. The full application in `examples/viewer` keeps its playback controls and demo behavior inside the example.

Supports orbit/pan/zoom; `frameModel`, `setGroup`, and `sync` are available on the controller. It reads compiled geom poses, primitive sizes, PBR colors and mesh triangles through portable API snapshots. The scene root converts MuJoCo Z-up to Scene Y-up once. It does not parse MJCF or recompute robot forward kinematics.

Supported geometry: plane, sphere, capsule, ellipsoid, cylinder, box and triangle mesh. Unsupported geom kinds are listed in `controller.warnings`. Infinite planes are visualized as finite patches. Textures, authored lights, hfields, flex, tendons and contact-force overlays are not implemented yet; material-backed floors use neutral gray when authored textures are unavailable. This is not yet a full replacement for every feature of the original MuJoCo viewer.

The package contains no native pointer imports. Numerical stepping still runs on the caller's isolate; a dedicated simulation isolate/worker is a future optimization, not something hidden in this widget.

See `example/main.dart` for a cross-platform widget example. Native runs require Flutter 3.47+ with Flutter GPU enabled; web uses Scene's WebGL2 backend. Flutter GPU's native enablement and supported targets follow Flutter Scene.
