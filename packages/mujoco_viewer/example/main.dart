import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mujoco_flutter/mujoco_flutter.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';

void main() => runApp(
  const Directionality(textDirection: TextDirection.ltr, child: Example()),
);

class Example extends StatefulWidget {
  const Example({super.key});
  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  MjModel? model;
  MjData? data;
  MjSceneState? initialState;
  final states = StreamController<MjSceneState>.broadcast();
  Timer? timer;
  final clock = Stopwatch();
  double accumulator = 0;
  Object? error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      await MujocoFlutter.initialize();
      if (!mounted) return;
      final model = MjModel.from_xml_string('''<mujoco><worldbody>
        <geom type="plane" size="0 0 0.1"/>
        <body pos="0 0 1"><freejoint/><geom type="sphere" size="0.2"/></body>
      </worldbody></mujoco>''');
      this.model = model;
      final data = MjData(model);
      this.data = data;
      mj_forward(model, data);
      initialState = MjSceneState.fromData(data);
      clock.start();
      // Physics runs independently of SceneView's render callbacks.
      timer = Timer.periodic(const Duration(milliseconds: 8), (_) {
        accumulator += (clock.elapsedMicroseconds / 1000000).clamp(0.0, .05);
        clock.reset();
        var changed = false;
        while (accumulator >= model.timestep) {
          mj_step(model, data);
          accumulator -= model.timestep;
          changed = true;
        }
        if (changed) {
          mj_forward(model, data);
          states.add(MjSceneState.fromData(data));
        }
      });
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    unawaited(states.close());
    data?.dispose();
    model?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff10171d),
    child: model == null || initialState == null
        ? Center(child: Text(error == null ? 'Loading MuJoCo…' : '$error'))
        : MujocoViewer(
            model: model!,
            states: states.stream,
            initialState: initialState,
          ),
  );
}
