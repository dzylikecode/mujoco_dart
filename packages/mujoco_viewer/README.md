# mujoco_viewer

A Flutter Scene viewer for a static MuJoCo model and a stream of immutable scene states, on native and web.

```dart
await MujocoFlutter.initialize();
final model = MjModel.from_xml_path('robot.xml', vfs: vfs);
final data = MjData(model);
mj_forward(model, data);
final states = StreamController<MjSceneState>.broadcast();
final initialState = MjSceneState.fromData(data);

// Place inside bounded Flutter layout constraints.
final widget = MujocoViewer(
  model: model,
  states: states.stream,
  initialState: initialState,
);

// In your independent physics loop, after advancing a batch of fixed steps:
mj_forward(model, data);
states.add(MjSceneState.fromData(data));
```

Import `dart:async`, `package:flutter/widgets.dart`, `package:mujoco_flutter/mujoco_flutter.dart`, and `package:mujoco_viewer/mujoco_viewer.dart`. The widget creates and owns its controller by default. For camera/group controls, create `MujocoViewerController.create(model: model)` and pass `controller:`; dispose that external controller after unmounting the widget.

Physics stepping, snapshot publication and rendering have separate schedules. The viewer retains only the latest received state and applies it at the next render frame. It never reads live `MjData` or advances physics. `initialState` is optional; without it, the surface stays empty until the first stream event. This also avoids losing an initial pose emitted before a broadcast stream is subscribed. Stream completion retains the final pose. Errors appear in the viewer, and a subsequent valid state resumes rendering. Replacing the stream cancels the previous subscription; replacing the model rebuilds the scene. Snapshots must come from the corresponding model; geom counts are checked, but same-sized models cannot be distinguished.

`MjSceneState.fromData(data)` copies packed geom positions and row-major rotations in MuJoCo Z-up coordinates. Its arrays are immutable, contain no native pointers, and remain valid after the source data/model is disposed. Run `mj_forward` after editing qpos or integrating steps before publishing. Snapshot publication need not happen on every physics step. For isolate/worker transport, reconstruct `MjSceneState(time:, positions:, rotations:)` from the received numerical payload.

The application owns model/data and the state producer. Stop production and unmount the widget before disposing external controllers and numerical resources. The viewer cancels its subscription but never closes the caller's stream. The example's timer is independent of rendering, while still sharing the UI isolate; true CPU isolation requires a separate isolate/worker.

The controller exposes camera and display controls:

```dart
final controller = await MujocoViewerController.create(model: model);
final widget = MujocoViewer(
  model: model,
  states: states.stream,
  initialState: initialState,
  controller: controller,
  maxFrameRate: 60, // Rendering only; physics keeps its own schedule.
  onStats: (stats) => print('${stats.fps} FPS'),
);
controller.focusOn(x: 0, y: 0, z: 1); // MuJoCo Z-up world coordinates.
controller.orbit.orbitBy(0.2, 0.1); // Azimuth/elevation deltas in radians.
controller.orbit.dollyBy(1); // Positive zooms in, negative zooms out.
controller.orbit.panBy(const Offset(0.1, 0)); // Viewport-relative panning.
controller.frameModel(); // Reframe model bounds, preserving the viewing angle.
controller.setGroup(3, true);
```

`onStats` reports measured render-loop FPS, average frame interval, interval count, and the latest snapshot's simulation time about once per second. It measures SceneView tick cadence, not physical display presentation or GPU completion. Empty/loading surfaces do not emit reports; paused physics still renders and reports FPS. `maxFrameRate` must be finite and positive, or null to follow display refresh. No per-frame parent rebuild is required.

`controller.camera.projection` supports Flutter Scene perspective/orthographic projections. `orbit` exposes gesture speed, smoothing and distance limits; its raw target is Scene Y-up, so use `focusOn` for MuJoCo coordinates. User drag/scroll gestures remain enabled. These controls only change visualization. Custom rendering loops can call controller `update(state)` and `sync(aspectRatio:)`. The scene root converts MuJoCo Z-up to Scene Y-up once; it does not recompute forward kinematics. See `example/main.dart` for a timer-driven example and `examples/viewer` for playback, drop loading, and model switching.

Supported geometry: plane, sphere, capsule, ellipsoid, cylinder, box and triangle mesh. Unsupported geom kinds are listed in `controller.warnings`. Infinite plane axes follow the camera with frustum-sized patches, snapped to whole texture periods so the ground remains visually continuous. Positive plane sizes retain their authored finite extent. Plane geoms use actual flat surfaces at the compiled pose. Authored 2D base-color textures (including MuJoCo builtin checker/cross images) are copied from the compiled model and rendered with texrepeat/texuniform mapping, mipmaps and color-space conversion. Untextured planes keep their authored RGBA; no forced floor color is applied. Cube/skybox textures, non-plane texture mapping, authored lights, hfields, flex, tendons and contact-force overlays are not implemented yet. This is not yet a full replacement for every feature of the original MuJoCo viewer.

The package contains no native pointer imports. Numerical stepping still runs on the caller's isolate; a dedicated simulation isolate/worker is a future optimization, not something hidden in this widget.

See `example/main.dart` for a cross-platform widget example. Native runs require Flutter 3.47+ with Flutter GPU enabled; web uses Scene's WebGL2 backend. Flutter GPU's native enablement and supported targets follow Flutter Scene.

Plane UV generation follows the [MuJoCo 3.12 classic renderer](https://github.com/google-deepmind/mujoco/blob/3.12.0/src/render/classic/render_gl3.c) and its [plane geometry](https://github.com/google-deepmind/mujoco/blob/3.12.0/src/render/classic/render_context.c). Flutter Scene lighting and tone mapping still differ from MuJoCo classic rendering.
