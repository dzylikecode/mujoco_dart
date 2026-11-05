## Unreleased — authored ground textures

- Render plane surfaces at the compiled pose with authored 2D textures, repeat settings and colors; remove the solid floor-color override.

## Unreleased — application-owned simulation loop

- Remove the public MujocoSimulation helper and simulation.dart entry point; playback logic lives in examples/viewer only.

## Unreleased — native / web split

- Remove Python support and backend selection.
- Add portable model visualization data and shared native/JS numerical API.
- Flutter integration and WASM assets live in mujoco_flutter / mujoco_web; visualization lives in the Flutter mujoco_viewer package.

## Unreleased

- Preserve covariant Python model/data parameters and let Dart enforce backend types.

- Add public Python interoperability, locked synchronous updates and deterministic viewer disposal.
- Reject native model/data before launching the Python passive viewer.

## 0.0.3

- update mujoco: 0.3.0
- refact the code: python api

## 0.0.2

- update mujoco dependency to ^0.0.4

## 0.0.1

- viewer support for the Dart MuJoCo package.
