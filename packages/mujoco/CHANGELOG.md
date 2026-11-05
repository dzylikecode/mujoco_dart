## Unreleased — authored ground textures

- Expose compiled texture snapshots and geom texture repeat metadata on native/web.

## Unreleased — internal backend integration

- Remove the js.dart and native.dart public entry points.
- Keep WASM registration behind an internal hook used by mujoco_flutter; expose numerical APIs through mujoco.dart only.

## Unreleased — explicit loading

- Add MjSpec and C-style parse/compile/load functions; retain thin from_xml_string/from_xml_path factories. Remove implicit assets-map loading in favor of explicit VFS.

## Unreleased — public virtual file system

- Expose reusable MjVfs on native and web, including addBuffer, deleteFile and explicit disposal.
- Allow both XML model factories to use a caller-owned VFS.

## Unreleased — application-owned simulation loop

- Remove the public MujocoSimulation helper and simulation.dart entry point; playback logic lives in examples/viewer only.

## Unreleased — explicit disposal

- Remove the resource_scope dependency, re-export and automatic tracking.
- Remove scope detach/promote APIs from model and data; callers own disposal.
- Retain idempotent dispose, isDisposed, guarded borrowed views and model/data validation on native and web.

## Unreleased — native / web split

- Remove Python support and backend selection.
- Add portable model visualization data and shared native/JS numerical API.
- Flutter integration and WASM assets live in mujoco_flutter / mujoco_web; visualization lives in the Flutter mujoco_viewer package.

## Unreleased

- Add backend-independent timestep, joint/actuator metadata and body force views.
- Keep model factories and physics operations delegated to the api abstraction.
- Add semantic sensor kinds and use primary constructors for metadata.

## 0.1.0

- 更新 py_embed 到 0.2.3
- 实现了 native backend ，支持切换 backend

## 0.0.4

- update py_embed to 0.1.0

## 0.0.3

- refact to factory pattern

## 0.0.2

- add `MjModel.fromXmlPath()` constructor

## 0.0.1

- python backend
