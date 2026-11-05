import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('mujocoDartLoad')
external JSPromise<JSObject> _loadMujoco();

abstract final class MujocoWeb {
  static Future<JSObject>? _pending;

  /// Loads local package assets. [assetBase] can override the directory URL.
  /// The default single-threaded WASM needs no cross-origin isolation headers.
  static Future<JSObject> initialize({String? assetBase}) =>
      _pending ??= _initialize(assetBase)
          .catchError((Object e, StackTrace stack) {
            _pending = null;
            Error.throwWithStackTrace(e, stack);
          });

  static Future<JSObject> _initialize(String? assetBase) async {
    if (!globalContext.hasProperty('mujocoDartLoad'.toJS).toDart) {
      final done = Completer<void>();
      final script = web.HTMLScriptElement()
        ..type = 'module'
        ..src = Uri.parse(web.document.baseURI)
            .resolve(assetBase ?? 'assets/packages/mujoco_web/assets/')
            .resolve('bootstrap.js')
            .toString();
      script.addEventListener(
        'load',
        ((web.Event _) {
          if (!done.isCompleted) done.complete();
        }).toJS,
      );
      script.addEventListener(
        'error',
        ((web.Event _) {
          if (!done.isCompleted) {
            done.completeError(
              StateError('Failed to load MuJoCo module: ${script.src}'),
            );
          }
        }).toJS,
      );
      web.document.head!.appendChild(script);
      try {
        await done.future.timeout(const Duration(seconds: 30));
      } catch (_) {
        script.remove();
        rethrow;
      }
    }
    return _loadMujoco().toDart.timeout(const Duration(seconds: 60));
  }
}
