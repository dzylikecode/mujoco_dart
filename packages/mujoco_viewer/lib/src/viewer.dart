import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_scene/scene.dart' as scene;
import 'package:mujoco/mujoco.dart';

import 'controller.dart';
import 'frame_stats.dart';

/// Renders the latest snapshot at Flutter's frame rate, independently of physics.
///
/// The widget owns its stream subscription and, unless supplied, its controller.
/// The caller owns the model and stream. An external controller must use [model]
/// and be disposed after this widget is unmounted. Until the first state arrives,
/// the viewer shows an empty surface; completion retains the final state.
class MujocoViewer extends StatefulWidget {
  const MujocoViewer({
    super.key,
    required this.model,
    required this.states,
    this.initialState,
    this.controller,
    this.onStats,
    this.maxFrameRate,
  });

  /// Receives render cadence about once per second while frames are ticking.
  ///
  /// Loading and empty surfaces do not produce reports. Simulation Hz and GPU
  /// completion are not measured. The callback may update UI without driving physics.
  final ValueChanged<MujocoViewerStats>? onStats;

  /// The render-loop FPS cap, or null to follow the display refresh rate.
  ///
  /// Must be finite and greater than zero. This does not cap physics updates.
  final double? maxFrameRate;

  final MjModel model;
  final Stream<MjSceneState> states;
  final MjSceneState? initialState;
  final MujocoViewerController? controller;

  @override
  State<MujocoViewer> createState() => _MujocoViewerState();
}

class _MujocoViewerState extends State<MujocoViewer> {
  StreamSubscription<MjSceneState>? _subscription;
  MujocoViewerController? _controller;
  MjSceneState? _latest;
  Object? _error;
  bool _ownsController = false;
  int _generation = 0;
  final _frameMeter = ViewerFrameMeter();

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(MujocoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.model, oldWidget.model) ||
        !identical(widget.controller, oldWidget.controller)) {
      _release();
      _bind();
    } else if (!identical(widget.states, oldWidget.states)) {
      unawaited(_subscription?.cancel());
      _error = null;
      _listen();
    }
  }

  void _bind() {
    final generation = ++_generation;
    _frameMeter.reset();
    _latest = widget.initialState;
    _error = null;
    final provided = widget.controller;
    if (provided != null && !identical(provided.model, widget.model)) {
      throw ArgumentError('Controller belongs to a different model');
    }
    _ownsController = provided == null;
    _controller = provided;
    _listen();
    if (provided != null) {
      if (_latest != null) provided.update(_latest!);
    } else {
      unawaited(_createController(generation));
    }
  }

  Future<void> _createController(int generation) async {
    try {
      final controller = await MujocoViewerController.create(
        model: widget.model,
      );
      if (!mounted || generation != _generation) {
        controller.dispose();
        return;
      }
      _controller = controller;
      if (_latest != null) controller.update(_latest!);
      setState(() {});
    } catch (error) {
      if (mounted && generation == _generation) setState(() => _error = error);
    }
  }

  void _listen() {
    final generation = _generation;
    _subscription = widget.states.listen(
      (state) {
        if (!mounted || generation != _generation) return;
        try {
          if (state.geomCount != widget.model.ngeom) {
            throw ArgumentError('State geom count does not match the model');
          }
          final first = _latest == null || _error != null;
          _latest = state;
          _controller?.update(state);
          if (first) {
            _frameMeter.reset();
            setState(() => _error = null);
          }
        } catch (error) {
          setState(() => _error = error);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (mounted && generation == _generation) {
          setState(() => _error = error);
        }
      },
    );
  }

  void _release() {
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (_ownsController) _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text('Viewer: $_error'));
    final maxFrameRate = widget.maxFrameRate;
    if (maxFrameRate != null && (!maxFrameRate.isFinite || maxFrameRate <= 0)) {
      throw ArgumentError.value(
        maxFrameRate,
        'maxFrameRate',
        'Must be finite and positive',
      );
    }
    final controller = _controller;
    if (controller == null || _latest == null) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, bounds) => scene.CameraControls(
        controller: controller.orbit,
        child: scene.SceneView(
          controller.world,
          maxFrameRate: maxFrameRate,
          onTick: (elapsed, dt) {
            controller.sync(aspectRatio: bounds.maxWidth / bounds.maxHeight);
            final stats = _frameMeter.tick(elapsed, _latest!.time);
            if (stats != null) widget.onStats?.call(stats);
          },
        ),
      ),
    );
  }
}
