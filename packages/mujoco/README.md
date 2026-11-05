# mujoco

Dart API for [MuJoCo](https://github.com/google-deepmind/mujoco).

## Native asset pruning

The build and link hooks share the `XmakeLibrary` in `lib/src/xmake.dart`, using
its default `.byPreference` mode and the dedicated `mujoco_dart` xmake target.
The `minimal` executable remains an independent C++ example.

A local recipe in `xmake_repo/packages/m/mujoco/xmake.lua`, following the
`cserialport` repository layout, owns the MuJoCo-specific build adjustments.
For AOT builds, its `export_c_api` configuration preserves C API visibility,
and `merge_static` merges the required dependencies into the package's installed
static archive. These configurations are part of the package cache key. The
project target only exports the finished library to
`dist/<os>/<architecture>/lib/libmujoco.a` (`mujoco.lib` on Windows).

The local recipe selects reentrant Qhull (`qhullstatic_r`) and excludes the extra
TinyObjLoader archive because MuJoCo already embeds it in `obj_decoder.cc`.
See [the local repository notes](xmake_repo/README.md) for the upstream recipe
revision, configuration constraints, and update instructions.
The link hook supplies the C++ runtime libraries and retains the FFI symbols
recorded by the Dart compiler. No recorded native calls means no MuJoCo library
in the final bundle; missing usage recordings conservatively retain all symbols.

Development builds install the original shared MuJoCo library directly from
the xmake package, rather than building a wrapper shared library. The build hook
tracks `xmake.lua`, `xmake-requires.lock`, and the local recipe so configuration
changes invalidate its cache.

Run the native smoke example and the AOT packaging checks from this package:

```sh
dart run example/native_smoke.dart
dart run tool/verify_native_assets.dart
```

The smoke example compiles a tetrahedral mesh and advances the simulation. The
verification script builds and runs both a used-native bundle and an unused
import bundle, checking whether the native library is included. It saves its
artifacts under `.dart_tool/native_assets_check/` for inspection.

The complete flow has been tested on Linux x64. Windows, macOS, Android, and iOS
branches have not been verified on their target platforms.

## Explicit ownership

`MjModel` and `MjData` own native or WASM resources. Dispose data before its
model, using `try/finally` when exceptions are possible:

```dart
import 'package:mujoco/mujoco.dart';

void main() {
  final model = MjModel.from_xml_path('robot.xml');
  MjData? data;
  try {
    data = MjData(model);
    mj_step(model, data);
  } finally {
    data?.dispose();
    model.dispose();
  }
}
```

`dispose()` is idempotent and `isDisposed` exposes the released state. Disposing
data does not dispose its model. Arrays, sensor readings and geom/body poses
borrow their owner's memory and need no separate disposal; accessing a borrowed
view after data or model disposal throws `StateError`. There is no automatic
scope tracking or detach/promote API.

## Virtual file system

`MjVfs` owns copied in-memory files on native and web. Add XML, includes, meshes
and textures under the paths used by MJCF, then compile using that VFS:

```dart
final vfs = MjVfs();
try {
  vfs.addBuffer('robot.xml', xmlBytes);
  vfs.addBuffer('body.xml', includeBytes);
  vfs.addBuffer('meshes/link.obj', meshBytes);
  final model = MjModel.from_xml_path('robot.xml', vfs: vfs);
  try {
    // Use the compiled model here.
  } finally {
    model.dispose();
  }
} finally {
  vfs.dispose();
}
```

`MjModel.from_xml_string(xml, vfs: vfs)` also resolves references through the
same VFS. Compiling does not consume or modify caller-owned files: reuse the VFS
for multiple models, or release it as soon as compilation finishes. Models and
data remain independent of its lifetime. Use `deleteFile(name)` before replacing
a file. Repeated `dispose()` is safe; loading or modifying a disposed VFS throws
`StateError`.

Resources are supplied through an explicit `vfs`; there is no `assets` map
parameter. On web, initialize the WASM module before constructing a VFS. Download URLs into bytes
or load them from a Flutter AssetBundle before adding files; VFS paths are not
network URLs. MuJoCo may fall back to the platform file system for missing files;
this API does not provide a file-system sandbox.

## Parsing and compilation

The intuitive `MjModel.from_xml_string(xml, vfs: vfs)` and
`MjModel.from_xml_path(path, vfs: vfs)` factories remain available. The string
factory parses, compiles and disposes its intermediate specification. The path
factory delegates to `mj_loadXML`.

For explicit control, use the C-style entry points:

```dart
final spec = mj_parseXMLString(xml, vfs: vfs);
late final MjModel model;
try {
  model = mj_compile(spec, vfs: vfs);
} finally {
  spec.dispose();
}
// Use model, then dispose it independently.
```

`MjSpec` owns an uncompiled specification. Parse failures and compile failures
throw `FormatException` separately. Compilation borrows its inputs: a spec may
compile multiple models, and models remain valid after spec/VFS disposal. If
compilation uses external meshes or textures, supply the asset VFS to
`mj_compile` as well as to parsing. All resource owners have idempotent
`dispose()`; compiling a disposed spec or using a disposed VFS throws `StateError`.

## Backend-independent model inspection

Factories and physics functions delegate to the selected `api` abstraction.
Native platforms use the C API directly. Browser builds use the official MuJoCo
JavaScript/WASM module through conditional imports. There is no Python backend,
`py_embed` dependency, global backend switch, or `python.dart` entry point.

For Flutter, call `MujocoFlutter.initialize()` from `mujoco_flutter` before using
models; on native this is a no-op. Browser module registration is an internal
handshake with the platform integration package. Applications import
`package:mujoco/mujoco.dart`; raw FFI bindings, native pointers and JS backend
classes are implementation details. The numerical package itself has no Flutter
dependency.

```dart
final model = MjModel.from_xml_path('robot.xml');
final data = MjData(model);
try {
  print(model.timestep);
  final actuator = model.actuatorById(0);
  print(actuator.joint?.qposAddress);
  print(actuator.controlRange);
  final base = data.body('base_link');
  print(base.position.toList());
  base.appliedForce.setAll(0, [0, 0, 10, 0, 0, 0]);
  mj_step(model, data);
} finally {
  data.dispose(); model.dispose();
}
```

`MjActuatorInfo`, `MjJointInfo` and `MjBodyInfo` are metadata snapshots; they
contain no pointers or Python objects. Body position and applied-force views
are live and reject access after their owner is disposed. The wrench contains
world-frame force xyz followed by torque xyz at the body's centre of mass.
`isUnitTorqueMotor` identifies a unit-gear, unit-gain joint force actuator;
applications can additionally check the joint type.

Sensor `type` retains the backend's raw enum number. For portable logic use
`sensor.kind` (`MjSensorKind`), since enum numbering can differ between versions.
Use matching engine versions when comparing native and web trajectories; this
workspace ships MuJoCo 3.12.0 for both. Floating-point tolerances still apply.

## Portable visual data and assets

`model.geomById` and `model.meshById` expose compiled rendering metadata without
native pointers. `data.geomPosition` and `data.geomRotation` are live guarded
views. `data.ncon` exposes the active contact count. Numerical code does not
import or depend on `mujoco_viewer`.

Use `MjVfs.addBuffer` to supply in-memory model resources on both backends.
Native paths can read the host filesystem; browser paths refer to MuJoCo's WASM
filesystem or an explicitly supplied VFS. Flutter applications choose their own
AssetBundle or network loading, then add the resulting bytes to the VFS.

## Compiled textures

`model.ntex` and `textureById(id)` expose copied texture pixels, dimensions, channel
count, texture type and color space on native and web. `MjGeomInfo` carries the
base-color texture ID and the material's `textureRepeat` / `textureUniform`
settings. Snapshots do not borrow engine memory and remain readable after model
disposal. The numerical package does not upload textures or depend on Flutter.
