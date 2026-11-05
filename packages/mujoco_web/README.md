# mujoco_web

Flutter package containing the official **MuJoCo 3.12.0 single-threaded WASM** and its ESM loader. No Python, CDN, npm installation or custom script tags are needed at application runtime.

Use `MujocoFlutter.initialize()` from `mujoco_flutter` for Flutter apps.
It loads the WASM module and registers it through the numerical package's
internal platform handshake. Applications then use the public `mujoco.dart`
API. `MujocoWeb.initialize()` from `package:mujoco_web/browser.dart` remains the
low-level engine asset loader used by the platform integration package.

Assets are served under `assets/packages/mujoco_web/assets/` relative to the document base URI. Override the loader's `assetBase` directory URL for custom hosting. Serve `.wasm` as `application/wasm`. The single-threaded build does not require COOP/COEP headers. Assets are declared web-only, so native Flutter builds do not bundle the 10MB WASM binary.

`UPSTREAM.json` records the npm source, version, archive integrity and SHA-256 of the upstream files. `LICENSE` contains the wrapper MIT license and upstream Apache-2.0 license. The WASM is unchanged. The JS carries one documented compatibility fix for upstream 3.12.0: register the missing Emscripten `memory_view<bool>` as a byte-sized Uint8Array. Without it, reading `actuator_ctrllimited` throws a BindingError. Refresh the checked-in assets from the locked official npm archive with:

```sh
dart run tool/update.dart
```

The updater downloads the archive from `UPSTREAM.json`, checks its SHA-512
integrity, package name/version and original JS/WASM SHA-256 hashes, then applies
the bool-view patch and writes both assets and the patch record. Validation
failures leave existing files untouched; write failures restore the old files.
It selects the single-threaded assets, not the `mt/` build. No npm, Node.js or
external tar command is needed.

For an already downloaded archive:

```sh
dart run tool/update.dart --archive /path/to/mujoco-3.12.0.tgz
```

This restores the **locked version**, rather than selecting the latest release.
To adopt another version, review and update the source, integrity and file hashes
in `UPSTREAM.json`, adapt the version-specific patch, and run the browser smoke
test. The current patch explicitly accepts only 3.12.0.

To apply only the patch to an original JS file:

```sh
dart run tool/patch_bool_views.dart /path/to/original/npm/mujoco.js
```

The script verifies the original JS hash and records the patched hash. It does not compile WASM or alter physics. Original package: https://www.npmjs.com/package/@mujoco/mujoco/v/3.12.0

This package only loads the engine; it neither defines model APIs nor renders a scene. Failed initialization can be retried. The Dart numerical API and browser module must use a single initialized WASM instance.
