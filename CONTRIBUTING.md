# Development

Resolve dependencies at the repository root with `flutter pub get`. Use the root
lockfile; member packages and the example declare `resolution: workspace` and
must not carry their own lockfiles or path overrides to other workspace members.

`./tool/check.sh` runs analysis and the numerical, Flutter integration, viewer
and example suites. Run native tests from `packages/mujoco` so Dart builds that
package's native assets. Optional AOT pruning checks are in that package's
`tool/verify_native_assets.dart`.

Run the demonstration from `examples/viewer`. Its default XML and smoke tests
are bundled here and do not need Cave, robot_engine, Python or external robot
assets. The optional LingLong command in its README refers to a developer's
local model checkout and is not needed for normal development.

Native MuJoCo uses the package's xmake build hook and locked recipe. The
repository retains generated ffigen bindings; regenerate them with
`packages/mujoco/tool/ffigen.dart` after exporting the upstream headers through
the package's existing xmake target. Do not edit generated bindings by hand.

The browser engine is checked in as versioned package assets. To update it,
run `dart run tool/update.dart` from `packages/mujoco_web`. It downloads the
archive locked in `UPSTREAM.json`, verifies it, extracts the single-threaded
JS/WASM, applies the compatibility patch and updates the asset records. Use
`--archive /path/to/package.tgz` for an offline archive. Adopting a new upstream
version requires reviewing the manifest hashes and version-specific patch first;
then run the browser smoke test in `examples/viewer`.

Each published package has its own version and changelog. Publishing requires a
separate explicit action; this workspace setup does not publish or push changes.

For an external local Flutter app, add overrides for all unpublished packages
needed by its dependency graph (`mujoco`, `mujoco_web`, `mujoco_flutter`,
`mujoco_viewer`) pointing into this checkout's `packages/` directory. A pure Dart
consumer only needs `mujoco`. Keep overrides in the consumer, not this workspace.
