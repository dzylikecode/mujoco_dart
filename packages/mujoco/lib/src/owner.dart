import 'base.dart';

mixin DisposableOwner {
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void dispose() {
    _isDisposed = true;
  }
}

/// A view that rejects access after its owner is disposed.
class GuardedDoubleListView(
  final MjDoubleListView source,
  final void Function() checkAlive,
) implements MjDoubleListView {
  @override
  int get length {
    checkAlive();
    return source.length;
  }

  @override
  double operator [](int index) {
    checkAlive();
    RangeError.checkValidIndex(index, this, 'index', source.length);
    return source[index];
  }

  @override
  void operator []=(int index, double value) {
    checkAlive();
    RangeError.checkValidIndex(index, this, 'index', source.length);
    source[index] = value;
  }

  @override
  List<double> toList() {
    checkAlive();
    return source.toList();
  }
}

void checkVfsFilename(String filename) {
  if (filename.isEmpty || filename.contains('\u0000')) {
    throw ArgumentError.value(
      filename,
      'filename',
      'Must be nonempty without NUL',
    );
  }
}
