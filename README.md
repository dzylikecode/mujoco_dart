# MuJoCo Dart

Bring [MuJoCo](https://github.com/google-deepmind/mujoco) to Dart and Flutter, with
native and browser WASM physics and a shared Flutter Scene viewer. No Python is
required by these packages.

## Workspace

This repository uses Dart's native pub workspace. The five members share one
root `pubspec.lock`; local package dependencies resolve inside the workspace
without path overrides or Melos.

```text
packages/
  mujoco/          Pure Dart numerical API: native FFI and JavaScript interop
  mujoco_web/      Official JS/WASM assets and browser loader for Flutter
  mujoco_flutter/  Unified native/web platform initialization
  mujoco_viewer/   Flutter Scene visualization widget and controller
examples/
  viewer/          Runnable Linux/Web application and browser smoke tests
docs/
  architecture.md Package boundaries, ownership, migration notes and limits
```

| Package | Purpose |
| --- | --- |
| [mujoco](packages/mujoco) | Pure Dart numerical API, compiled geometry metadata and resource lifetimes |
| [mujoco_web](packages/mujoco_web) | Locally bundled official MuJoCo 3.12.0 JS/WASM, declared as web-only assets |
| [mujoco_flutter](packages/mujoco_flutter) | Native/web initialization and numerical API exports |
| [mujoco_viewer](packages/mujoco_viewer) | Flutter viewer consuming a model and immutable scene-state stream |

## Get started

Use Flutter 3.47.8 / Dart 3.13.7 or newer for the full workspace. The numerical
`mujoco` package itself does not depend on Flutter.

```sh
flutter pub get
cd examples/viewer
flutter run -d linux --enable-flutter-gpu
# Or run in a browser; engine assets are loaded from this package:
flutter run -d chrome
```

The default demo is self-contained: an articulated pendulum, free bodies, mesh
and contacts. Local robot XML/STL files can be loaded on native. Browser models
use Flutter assets or uploaded XML/asset bytes rather than disk paths. See the
[example README](examples/viewer/README.md) for controls and browser smoke tests,
and the [architecture guide](docs/architecture.md) for API and ownership rules.

## Check the workspace

```sh
./tool/check.sh
# Optional native AOT asset-pruning verification:
cd packages/mujoco
dart run tool/verify_native_assets.dart
```

The check script runs strict static analysis and all 19 numerical/Flutter
regression tests from their correct package directories. Browser smoke and
DartWasm builds are separate checks documented in the viewer example.

## Repository scope

The four packages and viewer example moved here from Cave. Cave and
robot_engine are consumers, not workspace members. Repository URLs point here;
there are no required sibling checkout paths inside this workspace. External
local consumers can override only the packages they use with paths into this
repository. See [CONTRIBUTING.md](CONTRIBUTING.md).

The upstream WASM/JS source, integrity hashes, compatibility patch and licenses
are recorded in `packages/mujoco_web/UPSTREAM.json` and its README. Build caches,
compiled native libraries and generated Scene assets are not versioned.
