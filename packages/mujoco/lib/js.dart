/// JavaScript/WASM backend registration for browser or dart2js applications.
/// Load the official MuJoCo ESM module, then call [initializeMujocoJs] once.
library;

export 'src/backend/web.dart' show initializeMujocoJs, MjModelWeb, MjDataWeb;
