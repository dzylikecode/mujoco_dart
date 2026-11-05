/// Native MuJoCo API for model metadata and force buffers.
///
/// Raw pointers have the lifetime of their owning model/data. Dispose data
/// before its model and never use pointers afterwards.
library;

export 'src/backend/native.dart'
    show NativeApi, MjModelNative, MjDataNative, MjSpecNative, MjVfsNative;
export 'src/backend/native.g.dart';
