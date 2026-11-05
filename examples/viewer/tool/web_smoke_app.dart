import 'dart:convert';
import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart' as vm;

import 'package:flutter_scene_lab/model_assets.dart';
import 'package:flutter_scene_lab/simulation.dart';

import 'package:flutter/widgets.dart';
import 'package:mujoco_flutter/mujoco_flutter.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';

void report(Map<String, Object?> value) =>
    globalContext.setProperty('mujocoSmokeResult'.toJS, value.jsify());
void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  report({'status': 'loading'});
  runApp(
    const Directionality(textDirection: TextDirection.ltr, child: Smoke()),
  );
}

class Smoke extends StatefulWidget {
  const Smoke({super.key});
  @override
  State<Smoke> createState() => _SmokeState();
}

class _SmokeState extends State<Smoke> {
  MujocoSimulation? sim;
  MujocoViewerController? viewer;
  Object? error;
  final firstStats = Completer<MujocoViewerStats>();
  @override
  void initState() {
    super.initState();
    run();
  }

  Future<void> run() async {
    try {
      await MujocoFlutter.initialize();
      final loaded = await loadBundledDemo();
      sim = MujocoSimulation.model(loaded);
      final s = sim!;
      check(s.version == '3.12.0', 'WASM version mismatch');
      check(s.geomCount == 9 && s.model.nmesh == 1, 'Wrong demo model');
      final floor = s.model.geomById(0);
      check(
        floor.colorTextureId >= 0 && floor.textureUniform,
        'Ground material metadata failed',
      );
      final texture = s.model.textureById(floor.colorTextureId);
      check(
        texture.type == MjTextureType.twoD &&
            texture.width == 512 &&
            texture.height == 512,
        'Compiled ground texture layout failed',
      );
      check(
        texture.pixels.length ==
            texture.width * texture.height * texture.channels,
        'Compiled ground texture pixels failed',
      );
      check(
        floor.textureRepeat[0] == 1 && floor.textureRepeat[1] == 1,
        'Ground repeat failed',
      );
      final textureModel = MjModel.from_xml_string(
        '''<mujoco><asset>
        <texture name="sky" type="skybox" builtin="gradient" rgb1="0 0 0" rgb2="1 1 1" width="4" height="4"/>
        <texture name="check" type="2d" builtin="checker" rgb1="1 0 0" rgb2="0 0 1" width="8" height="8"/>
        <material name="floor" texture="check" texrepeat="2 3" texuniform="true"/>
        </asset><worldbody><geom type="plane" size="2 3 .1" material="floor"/></worldbody></mujoco>''',
      );
      try {
        final geom = textureModel.geomById(0);
        final copied = textureModel.textureById(geom.colorTextureId);
        check(
          geom.colorTextureId == 1 &&
              copied.channels == 3 &&
              copied.pixels.length == 192,
          'Nonzero texture address failed',
        );
        final colors = <String>{};
        for (var i = 0; i < copied.pixels.length; i += 3) {
          colors.add(copied.pixels.sublist(i, i + 3).join(','));
        }
        check(
          colors.contains('255,0,0') && colors.contains('0,0,255'),
          'Compiled checker colors failed',
        );
        textureModel.dispose();
        check(copied.pixels.length == 192, 'Texture snapshot lifetime failed');
      } finally {
        textureModel.dispose();
      }
      final z = s.data.qpos[3];
      for (var i = 0; i < 100; i++) {
        s.singleStep();
      }
      check(
        (s.time - 0.2).abs() < 1e-9 && s.data.qpos[3] < z,
        'Gravity/time failed',
      );
      check(
        (s.data.geomPosition(5)[2] - s.data.qpos[3]).abs() < 1e-9,
        'Geom pose out of sync',
      );
      final vfs = MjVfs();
      final vfsModels = <MjModel>[];
      try {
        final xml = Uint8List.fromList(
          utf8.encode('<mujoco><include file="body.xml"/></mujoco>'),
        );
        vfs.addBuffer('robot.xml', xml);
        xml.fillRange(0, xml.length, 0);
        vfs.addBuffer(
          'body.xml',
          Uint8List.fromList(
            utf8.encode(
              '<mujoco><worldbody><body pos="0 0 1"><freejoint/>'
              '<geom type="sphere" size=".1"/></body></worldbody></mujoco>',
            ),
          ),
        );
        vfsModels.add(mj_loadXML('robot.xml', vfs: vfs));
        vfsModels.add(
          compileXml('<mujoco><include file="body.xml"/></mujoco>', vfs: vfs),
        );
        var duplicateRejected = false;
        try {
          vfs.addBuffer(
            'robot.xml',
            Uint8List.fromList(utf8.encode('<mujoco/>')),
          );
        } on StateError {
          duplicateRejected = true;
        }
        check(duplicateRejected, 'Duplicate VFS file was not rejected');
        vfs.deleteFile('robot.xml');
        vfs.deleteFile('robot.xml'); // Missing files are harmless.
        vfs.addBuffer(
          'robot.xml',
          Uint8List.fromList(utf8.encode('<mujoco/>')),
        );
        final replacement = mj_loadXML('robot.xml', vfs: vfs);
        check(replacement.nq == 0, 'VFS file replacement failed');
        replacement.dispose();
        vfs.dispose();
        vfs.dispose();
        check(vfs.isDisposed, 'VFS disposal state failed');
        for (final model in vfsModels) {
          final data = MjData(model);
          try {
            mj_step(model, data);
            check(
              data.time > 0 && model.nq == 7,
              'Model depended on disposed VFS',
            );
          } finally {
            data.dispose();
          }
        }
        var rejected = false;
        try {
          mj_loadXML('robot.xml', vfs: vfs);
        } on StateError {
          rejected = true;
        }
        check(rejected, 'Disposed VFS remained loadable');
      } finally {
        vfs.dispose();
        for (final model in vfsModels) {
          model.dispose();
        }
      }
      s.reset(demoPose: true);
      s.motor = 1;
      s.singleStep();
      check(s.data.ctrl[0] == 1, 'Control typed array write failed');
      check(
        s.model.actuatorById(0).joint?.name == 'hinge',
        'Actuator metadata failed',
      );
      final mesh = s.model.meshById(0);
      check(
        mesh.triangleCount == 4 && mesh.normals.every((v) => v.isFinite),
        'Mesh snapshot failed',
      );
      // Independent model exercises typed force views, sensor metadata, VFS and disposal.
      final model = compileXml('''<mujoco><worldbody>
        <body name="ball" pos="0 0 1"><freejoint/><geom type="sphere" size=".1"/>
        <site name="imu"/></body></worldbody>
        <sensor><gyro name="gyro" site="imu"/></sensor></mujoco>''');
      final data = MjData(model);
      mj_forward(model, data);
      data.body('ball').appliedForce.setAll(0, [1, 2, 3, 4, 5, 6]);
      check(
        List.generate(
          6,
          (i) => data.body('ball').appliedForce[i] == i + 1,
        ).every((v) => v),
        'Force view offset failed',
      );
      check(
        model.sensor('gyro').kind == MjSensorKind.gyro,
        'Sensor kind failed',
      );
      mj_step(model, data);
      final borrowed = data.qpos;
      data.dispose();
      data.dispose();
      model.dispose();
      model.dispose();
      check(
        data.isDisposed && model.isDisposed,
        'Explicit disposal state failed',
      );
      var rejected = false;
      try {
        borrowed[0];
      } on StateError {
        rejected = true;
      }
      check(rejected, 'Disposed typed view remained readable');
      final meshVfs = MjVfs();
      try {
        meshVfs.addBuffer(
          'tetra.obj',
          Uint8List.fromList(
            utf8.encode(
              'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\nf 1 3 2\nf 1 2 4\nf 1 4 3\nf 2 3 4\n',
            ),
          ),
        );
        final assetModel = compileXml(
          '<mujoco><asset><mesh name="tetra" file="tetra.obj"/></asset>'
          '<worldbody><geom type="mesh" mesh="tetra"/></worldbody></mujoco>',
          vfs: meshVfs,
        );
        try {
          check(
            assetModel.nmesh == 1 && assetModel.meshById(0).triangleCount == 4,
            'VFS asset compilation failed',
          );
        } finally {
          assetModel.dispose();
        }
      } finally {
        meshVfs.dispose();
      }
      s.reset(demoPose: true);
      final controller = await MujocoViewerController.create(model: s.model);
      if (!mounted) {
        controller.dispose();
        s.dispose();
        return;
      }
      setState(() => viewer = controller);
      await WidgetsBinding.instance.endOfFrame;
      s.reset(demoPose: true);
      s.reset();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final bob = controller.nodes[4]!.localTransform.getTranslation();
      check(
        (bob.z - s.geomPosition(4)[2]).abs() < 1e-6,
        'Viewer failed to apply the newest streamed snapshot',
      );
      final savedBob = bob.clone();
      // Unpublished live changes must never leak into the rendered scene.
      s.data.qpos[0] = .9;
      mj_forward(s.model, s.data);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      check(
        (controller.nodes[4]!.localTransform.getTranslation() - savedBob)
                .length <
            1e-6,
        'Viewer read live data without a published snapshot',
      );
      s.reset(demoPose: true);
      final originalPose = s.data.geomPosition(0).toList();
      final distance = controller.orbit.distance;
      controller.focusOn(x: 10000, y: 10000, z: 0);
      check(
        controller.orbit.target == vm.Vector3(10000, 0, -10000),
        'Camera focus failed to convert MuJoCo Z-up coordinates',
      );
      controller.orbit.orbitBy(.2, .1);
      controller.orbit.dollyBy(1);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final patch = controller.nodes[0]!.children.first.position;
      check(
        patch.x > 9900 && patch.y > 9900 && patch.z == 0,
        'Infinite ground did not follow the distant camera',
      );
      check(
        s.data.geomPosition(0).toList().join(',') == originalPose.join(','),
        'Visual recentering changed the physical plane',
      );
      check(
        controller.orbit.distance < distance,
        'Camera dolly control failed',
      );
      controller.frameModel();
      final stats = await firstStats.future.timeout(
        const Duration(seconds: 15),
      );
      check(
        stats.fps > 0 && stats.fps <= 35 && stats.frames > 0,
        'Render cadence report or frame-rate cap failed',
      );
      report({
        'status': 'passed',
        'version': s.version,
        'geoms': s.geomCount,
        'meshes': s.model.nmesh,
        'checks': [
          'gravity',
          'fixed step',
          'geom poses',
          'control arrays',
          'actuator metadata',
          'mesh snapshots',
          'body force views',
          'sensor metadata',
          'disposed views',
          'VFS assets',
          'compiled ground texture and repeat',
          'public VFS ownership and reuse',
          'Flutter viewer mounted',
          'latest streamed state and no live data reads',
          'render FPS reports and independent cap',
          'camera focus, orbit and dolly controls',
          'infinite plane follows distant camera without moving physics',
        ],
      });
    } catch (e, stack) {
      report({'status': 'failed', 'error': '$e', 'stack': '$stack'});
      if (mounted) setState(() => error = e);
    }
  }

  @override
  void dispose() {
    viewer?.dispose();
    sim?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xff10171d),
    child: viewer == null
        ? Center(child: Text(error == null ? 'Loading WASM…' : '$error'))
        : MujocoViewer(
            model: sim!.model,
            states: sim!.states,
            initialState: sim!.state,
            controller: viewer!,
            maxFrameRate: 30,
            onStats: (stats) {
              if (!firstStats.isCompleted) firstStats.complete(stats);
            },
          ),
  );
}

MjModel compileXml(String xml, {MjVfs? vfs}) {
  final spec = mj_parseXMLString(xml, vfs: vfs);
  try {
    return mj_compile(spec, vfs: vfs);
  } finally {
    spec.dispose();
  }
}
