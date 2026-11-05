# mujoco_flutter

Unified Flutter initialization for native MuJoCo and the browser WASM backend.
Depends on `mujoco` for the pure Dart numerical API and `mujoco_web` for
browser-only engine assets. Does not depend on a renderer or Python.

```dart
import 'package:flutter/services.dart';
import 'package:mujoco_flutter/mujoco_flutter.dart';

await MujocoFlutter.initialize(); // native: no-op; web: load/register WASM once
final vfs = MjVfs();
late final MjModel model;
try {
  for (final entry in {
    'robot.xml': 'assets/robot.xml',
    'meshes/body.stl': 'assets/meshes/body.stl',
  }.entries) {
    final bytes = await rootBundle.load(entry.value);
    vfs.addBuffer(entry.key, bytes.buffer.asUint8List(
      bytes.offsetInBytes, bytes.lengthInBytes,
    ));
  }
  model = MjModel.from_xml_path('robot.xml', vfs: vfs);
} finally {
  vfs.dispose();
}
final data = MjData(model);
try {
  mj_step(model, data);
} finally {
  data.dispose();
  model.dispose();
}
```

Applications own resource loading and path mapping. Declare bundled files in the
application's `pubspec.yaml`, and add all referenced includes, meshes and textures
to the VFS. Network responses and dropped file bytes use the same numerical API.
There is no package-level `loadAsset` convenience method.

`MjModel.from_xml_string` and `from_xml_path` work on native and web. Explicit
parsing/compilation is available through `mj_parseXMLString`, `MjSpec` and
`mj_compile`; `mj_loadXML` directly loads and compiles a virtual or native path.
Browser local files must be read into memory rather than opened as host paths.
