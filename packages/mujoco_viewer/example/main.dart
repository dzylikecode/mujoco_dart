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
  double accumulator = 0;
  MujocoViewerController? viewer;
  Object? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    MjModel? loadedModel;
    MjData? loadedData;
    MujocoViewerController? controller;
    try {
      await MujocoFlutter.initialize();
      final spec = mj_parseXMLString('''<mujoco><worldbody>
        <geom type="plane" size="3 3 0.1"/>
        <body pos="0 0 1"><freejoint/><geom type="sphere" size="0.2"/></body>
      </worldbody></mujoco>''');
      try {
        loadedModel = mj_compile(spec);
      } finally {
        spec.dispose();
      }
      loadedData = MjData(loadedModel);
      mj_forward(loadedModel, loadedData);
      controller = await MujocoViewerController.create(
        model: loadedModel,
        data: loadedData,
      );
      if (!mounted) {
        controller.dispose();
        loadedData.dispose();
        loadedModel.dispose();
        return;
      }
      setState(() {
        model = loadedModel;
        data = loadedData;
        viewer = controller;
      });
    } catch (e) {
      controller?.dispose();
      loadedData?.dispose();
      loadedModel?.dispose();
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    viewer?.dispose();
    data?.dispose();
    model?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff10171d),
    child: viewer == null
        ? Center(child: Text(error == null ? 'Loading MuJoCo…' : '$error'))
        : MujocoViewer(
            controller: viewer!,
            onTick: (_, dt) {
              final model = this.model!;
              final data = this.data!;
              accumulator += dt.clamp(0.0, 0.05);
              while (accumulator >= model.timestep) {
                mj_step(model, data);
                accumulator -= model.timestep;
              }
              mj_forward(model, data);
            },
          ),
  );
}
