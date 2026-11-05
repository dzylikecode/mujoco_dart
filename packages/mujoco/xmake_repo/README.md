# Local MuJoCo package

This follows the `xmake_repo` layout used by `cserialport`. The recipe is based
on xmake-repo commit `a32d7e4ed13b8bbb8563c5cc4ee415fa333fd040`, restricted to
MuJoCo 3.12.0. Its upstream source archive URL and SHA-256 remain unchanged.

Two optional configurations are included in the xmake package cache key:

- `export_c_api`: preserve C API visibility when building a static archive that
  will later be relinked into a shared library. Consumers still receive
  `MJ_STATIC`; only compilation of the library itself uses the export macro.
- `merge_static`: after installation, merge the core MuJoCo archive with libccd,
  lodepng, reentrant Qhull, tinyxml2, and miniz into the installed MuJoCo archive.
  Non-reentrant Qhull/Qhull C++ archives are excluded, as is external TinyObjLoader
  because MuJoCo 3.12 already compiles that implementation in obj_decoder.cc.
  Shared dependencies and optional simulate/USD builds are unsupported in this
  configuration and are rejected.

The project's `mujoco_dart` target only copies this package's finished library to
Dart's platform installation directory. No merging or dependency filtering is
performed by the project or by native_toolchain_xmake.

To verify the integrated used/unused AOT paths from the MuJoCo package root:

```sh
dart run tool/verify_native_assets.dart
```

After changing installation patches in the local recipe, rebuild the cached
package with `xmake require -f mujoco` in the desired shared/static configuration.
Tracking the recipe in the Dart build hook reruns xmake, but does not by itself
force an already-installed xmake package to be rebuilt.

This is a project-local recipe, not a change published to xmake-repo. Only Linux
x64 has been validated. The recipe snapshot should be reviewed when updating
MuJoCo or its dependencies.
