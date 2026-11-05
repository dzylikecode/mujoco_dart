/// Render-loop statistics for one measurement window, independent of physics.
///
/// These measure SceneView frame cadence, not GPU completion or simulation Hz.
class const MujocoViewerStats({
  required final double fps,
  required final Duration averageFrameTime,
  required final int frames,
  required final double stateTime,
});

/// Accumulates render ticks without rebuilding the widget every frame.
class ViewerFrameMeter {
  Duration? _previous;
  Duration _window = Duration.zero;
  int _frames = 0;

  MujocoViewerStats? tick(Duration elapsed, double stateTime) {
    final previous = _previous;
    _previous = elapsed;
    if (previous == null || elapsed <= previous) {
      _window = Duration.zero;
      _frames = 0;
      return null;
    }
    _window += elapsed - previous;
    _frames++;
    if (_window < const Duration(seconds: 1)) return null;
    final result = MujocoViewerStats(
      fps: _frames * 1000000 / _window.inMicroseconds,
      averageFrameTime: Duration(
        microseconds: (_window.inMicroseconds / _frames).round(),
      ),
      frames: _frames,
      stateTime: stateTime,
    );
    _window = Duration.zero;
    _frames = 0;
    return result;
  }

  void reset() {
    _previous = null;
    _window = Duration.zero;
    _frames = 0;
  }
}
