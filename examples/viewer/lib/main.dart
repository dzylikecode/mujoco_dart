import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:desktop_drop/desktop_drop.dart';

import 'package:material_ui/material_ui.dart';

import 'package:mujoco_flutter/mujoco_flutter.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';

import 'model_assets.dart';
import 'model_path_stub.dart' if (dart.library.io) 'model_path_native.dart';
import 'simulation.dart';
import 'imported_models.dart';
import 'model_library.dart';

void main() => runApp(const SceneLab());

class SceneLab extends StatelessWidget {
  const SceneLab({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'MuJoCo / Flutter Viewer',
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: const Color(0xff10171d),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xffb8ed83),
        brightness: Brightness.dark,
      ),
    ),
    home: const Viewer(),
  );
}

class Viewer extends StatefulWidget {
  const Viewer({super.key});
  @override
  State<Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<Viewer> {
  ImportedModels? imported;
  String? selectedXml;
  bool readingDrop = false;
  bool dragging = false;
  MujocoSimulation? simulation;
  MujocoViewerController? rendering;
  final path = TextEditingController(
    text: const String.fromEnvironment('MUJOCO_MODEL'),
  );
  Timer? stats;
  bool playing = false;
  bool loading = true;
  bool demo = true;
  bool _released = false;
  String? error;
  String modelName = 'Physics lab';
  double stepMilliseconds = 0;
  int frames = 0;
  int fps = 0;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    load(path.text.isEmpty ? null : path.text);
    stats = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          fps = frames;
          frames = 0;
        });
      }
    });
  }

  Future<bool> load(String? filename, {ImportedModels? source}) async {
    if ((loading && simulation != null) || (readingDrop && source == null)) {
      return false;
    }
    setState(() {
      loading = true;
      playing = false;
      error = null;
    });
    // Unmount the old SceneView before releasing its scene and native owners.
    await WidgetsBinding.instance.endOfFrame;
    MujocoSimulation? candidate;
    MujocoViewerController? candidateScene;
    try {
      await MujocoFlutter.initialize();
      candidate = filename == null
          ? MujocoSimulation.model(await loadBundledDemo())
          : MujocoSimulation.model(
              source == null ? loadLocalModel(filename) : source.load(filename),
            );
      candidate.reset(demoPose: filename == null);
      candidateScene = await MujocoViewerController.create(
        model: candidate.model,
        data: candidate.data,
      );
      if (!mounted) {
        candidateScene.dispose();
        candidate.dispose();
        return false;
      }
      final previousScene = rendering;
      final previousSim = simulation;
      setState(() {
        simulation = candidate;
        rendering = candidateScene;
        demo = filename == null;
        modelName = filename == null
            ? 'Physics lab'
            : source == null
            ? modelLabel(filename)
            : filename;
        selectedXml = source == null ? null : filename;
        loading = false;
        playing = filename == null;
        generation++;
      });
      previousScene?.dispose();
      previousSim?.dispose();
      return true;
    } catch (e) {
      candidateScene?.dispose();
      candidate?.dispose();
      if (mounted) {
        setState(() {
          loading = false;
          error = '$e';
        });
      }
      return false;
    }
  }

  Future<void> receiveDrop(DropDetails details) async {
    if (loading || readingDrop) return;
    setState(() {
      readingDrop = true;
      dragging = false;
      playing = false;
      error = null;
    });
    ImportedModels? candidate;
    try {
      await MujocoFlutter.initialize();
      candidate = await readDroppedModels(details.items);
      if (!mounted) {
        candidate.dispose();
        return;
      }
      final previous = imported;
      setState(() {
        imported = candidate;
        selectedXml = candidate!.xmlPaths.first;
      });
      previous?.dispose();
      await load(candidate.xmlPaths.first, source: candidate);
    } catch (e) {
      if (!identical(imported, candidate)) candidate?.dispose();
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => readingDrop = false);
    }
  }

  Future<void> selectXml(String filename) async {
    if (loading || readingDrop) return;
    setState(() => selectedXml = filename);
    await load(filename, source: imported);
  }

  Widget library({bool inDrawer = false}) => ModelLibrary(
    paths: imported?.xmlPaths ?? const [],
    selected: selectedXml,
    busy: loading || readingDrop,
    fileCount: imported?.fileCount ?? 0,
    onSelected: (filename) {
      if (inDrawer) Navigator.of(context).pop();
      selectXml(filename);
    },
    onDemo: () {
      if (inDrawer) Navigator.of(context).pop();
      load(null);
    },
  );

  void tick(double dt) {
    final sim = simulation;
    final view = rendering;
    if (sim == null || view == null || loading || readingDrop) return;
    final watch = Stopwatch()..start();
    if (playing) sim.advance(dt);
    watch.stop();
    stepMilliseconds = watch.elapsedMicroseconds / 1000;
    frames++;
  }

  void release() {
    if (_released) return;
    _released = true;
    stats?.cancel();
    rendering?.dispose();
    simulation?.dispose();
    imported?.dispose();
  }

  @override
  void dispose() {
    release();
    path.dispose();
    super.dispose();
  }

  Widget panel() {
    final loading = this.loading || readingDrop;
    final sim = simulation;
    final view = rendering;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kIsWeb ? 'WASM PHYSICS / WEBGL2' : 'NATIVE PHYSICS / FLUTTER GPU',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.7,
              color: Color(0xffb8ed83),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'MuJoCo viewer',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(modelName, style: const TextStyle(color: Colors.white60)),
          const SizedBox(height: 20),
          if (sim != null) ...[
            Text('MuJoCo ${sim.version} · ${kIsWeb ? 'WASM' : 'native C API'}'),
            const SizedBox(height: 8),
            Text(
              't ${sim.time.toStringAsFixed(3)} s  ·  dt ${sim.timestep} s\n'
              '${sim.model.nq} qpos  /  ${sim.model.nv} DOF  /  ${sim.model.nu} controls\n'
              '${view?.nodes.length}/${sim.geomCount} geoms  ·  ${sim.contacts} contacts\n'
              '$fps FPS  ·  step + sync ${stepMilliseconds.toStringAsFixed(2)} ms',
              style: const TextStyle(
                color: Colors.white54,
                height: 1.8,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: loading
                      ? null
                      : () => setState(() => playing = !playing),
                  icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  label: Text(playing ? 'Pause' : 'Run'),
                ),
                OutlinedButton(
                  onPressed: playing || loading
                      ? null
                      : () => setState(() {
                          sim.singleStep();
                          view?.sync();
                        }),
                  child: const Text('Step'),
                ),
                OutlinedButton(
                  onPressed: loading
                      ? null
                      : () => setState(() {
                          sim.reset(demoPose: demo);
                          view?.sync();
                        }),
                  child: const Text('Reset'),
                ),
                OutlinedButton(
                  onPressed: loading ? null : sim.kick,
                  child: const Text('Kick DOF 0'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Speed'),
                const SizedBox(width: 16),
                DropdownButton<double>(
                  value: sim.speed,
                  items: [0.1, 0.25, 0.5, 1.0, 2.0]
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text('${s}x')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => sim.speed = v!),
                ),
              ],
            ),
            if (sim.model.nu > 0) ...[
              Text('Actuator 0   ${sim.motor.toStringAsFixed(2)}'),
              Slider(
                value: sim.motor,
                min: -5,
                max: 5,
                onChanged: (v) => setState(() => sim.motor = v),
              ),
            ],
            if (view != null)
              Wrap(
                spacing: 6,
                children: (view.groups.toList()..sort())
                    .map(
                      (g) => FilterChip(
                        label: Text('Group $g'),
                        selected: !view.hiddenGroups.contains(g),
                        onSelected: (v) => setState(() => view.setGroup(g, v)),
                      ),
                    )
                    .toList(),
              ),
            TextButton(
              onPressed: view?.frameModel,
              child: const Text('Frame model'),
            ),
          ],
          const Divider(height: 28),
          if (!kIsWeb) ...[
            TextField(
              controller: path,
              decoration: const InputDecoration(
                labelText: 'Local MJCF / XML path',
                hintText: '/path/to/robot.xml',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty && !loading) load(v.trim());
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: loading
                      ? null
                      : () {
                          if (path.text.trim().isNotEmpty) {
                            load(path.text.trim());
                          }
                        },
                  child: const Text('Load XML'),
                ),
                TextButton(
                  onPressed: loading ? null : () => load(null),
                  child: const Text('Demo'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Local models open paused. Mesh files and includes resolve relative to the XML. '
            'No stabilizing controller is applied; free robots will fall when Run is pressed.',
            style: TextStyle(fontSize: 11, height: 1.6, color: Colors.white54),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SelectableText(
                error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          if (view != null && view.warnings.isNotEmpty)
            Text(
              view.warnings.join('\n'),
              style: const TextStyle(color: Colors.orangeAccent),
            ),
        ],
      ),
    );
  }

  Widget viewport() => Stack(
    children: [
      Positioned.fill(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : rendering == null
            ? const Center(child: Text('Load a MuJoCo model to begin'))
            : MujocoViewer(
                controller: rendering!,
                key: ValueKey(generation),
                onTick: (_, dt) => tick(dt),
              ),
      ),
      const Positioned(
        left: 24,
        top: 24,
        child: Text(
          'MUJOCO → SCENE',
          style: TextStyle(
            letterSpacing: 3,
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      ),
      if (error != null)
        Positioned(
          left: 24,
          right: 24,
          top: 58,
          child: Container(
            padding: const EdgeInsets.all(12),
            color: const Color(0xee3c2720),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
          ),
        ),
      const Positioned(
        left: 24,
        bottom: 24,
        child: Text(
          'Drag to orbit · Scroll to zoom · Right drag to pan',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'SCENE / SIMULATION LAB',
        style: TextStyle(fontSize: 15, letterSpacing: 3),
      ),
    ),
    drawer: Drawer(child: SafeArea(child: library(inDrawer: true))),
    body: DropTarget(
      acceptedKinds: const {DropItemKind.file, DropItemKind.directory},
      enabled: !loading && !readingDrop,
      onDrop: receiveDrop,
      onEnter: (_) => setState(() => dragging = true),
      onLeave: () => setState(() => dragging = false),
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, bounds) => bounds.maxWidth > 1100
                  ? Row(
                      children: [
                        SizedBox(width: 250, child: library()),
                        Expanded(child: viewport()),
                        SizedBox(width: 330, child: panel()),
                      ],
                    )
                  : bounds.maxWidth > 850
                  ? Row(
                      children: [
                        Expanded(child: viewport()),
                        SizedBox(width: 330, child: panel()),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: viewport()),
                        SizedBox(height: 330, child: panel()),
                      ],
                    ),
            ),
          ),
          if (dragging || readingDrop)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: const Color(0xdd10171d),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (readingDrop)
                          const CircularProgressIndicator()
                        else
                          const Icon(
                            Icons.drive_folder_upload_outlined,
                            size: 56,
                            color: Color(0xffb8ed83),
                          ),
                        const SizedBox(height: 18),
                        Text(
                          readingDrop
                              ? 'Reading model files…'
                              : 'Drop model files or a folder',
                          style: const TextStyle(fontSize: 22),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'XML models and their assets stay together.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
