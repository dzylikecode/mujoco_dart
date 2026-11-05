/// Official, locally bundled single-threaded MuJoCo WASM for Flutter web.
library;

export 'src/loader_stub.dart'
    if (dart.library.js_interop) 'src/loader_web.dart';
