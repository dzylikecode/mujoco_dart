/// This asset loader is only available in a browser.
abstract final class MujocoWeb {
  static Future<void> initialize({String? assetBase}) => Future.error(
    UnsupportedError(
      'MuJoCo WASM requires a browser; use mujoco_flutter on native',
    ),
  );
}
