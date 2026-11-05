import 'dart:io';

import 'package:mujoco/mujoco.dart';

import 'dart:math' as math;

import 'package:flutter_scene_lab/simulation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart'
    show geomTransform, viewerPosition;
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  late MujocoSimulation sim;
  setUp(
    () => sim = MujocoSimulation.xml(
      File('assets/physics_lab.xml').readAsStringSync(),
    ),
  );
  tearDown(() => sim.dispose());

  test(
    'Simulation publishes owned states and runs without a rendering widget',
    () async {
      final received = <MjSceneState>[];
      final subscription = sim.states.listen(received.add);
      sim.start();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      sim.pause();
      await Future<void>.delayed(Duration.zero);
      expect(sim.time, greaterThan(0));
      expect(received, isNotEmpty);
      final paused = sim.time;
      final snapshot = received.last;
      final saved = snapshot.positions.toList();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(sim.time, paused);
      sim.reset();
      sim.singleStep();
      sim.kick();
      await Future<void>.delayed(Duration.zero);
      expect(received[received.length - 3].time, 0);
      expect(received.last.time, closeTo(sim.timestep, 1e-12));
      expect(snapshot.positions, saved);
      sim.dispose();
      await subscription.asFuture<void>();
    },
  );

  // 原生步进必须推进时间并产生重力运动，不能用画面动画代替物理状态。
  test('Native physics advances time and moves a free body under gravity', () {
    final before = sim.data.qpos.toList();
    for (var i = 0; i < 100; i++) {
      sim.singleStep();
    }
    expect(sim.time, closeTo(0.2, 1e-10));
    expect(sim.data.qpos[3], lessThan(before[3]));
    expect(sim.geomPosition(5)[2], closeTo(sim.data.qpos[3], 1e-10));
    expect(sim.steps, 100);
  });

  // 固定步长积累应该与帧率无关；重置后不保留上次累积时间。
  test(
    'Frame accumulation preserves fixed timesteps and reset clears state',
    () {
      sim.advance(0.003);
      sim.advance(0.003);
      expect(sim.time, closeTo(0.006, 1e-10));
      sim.motor = 1;
      sim.reset(demoPose: true);
      expect(sim.time, 0);
      expect(sim.steps, 0);
      expect(sim.data.qpos[0], closeTo(0.75, 1e-10));
      sim.advance(0.001);
      expect(sim.time, 0);
      sim.advance(0.001);
      expect(sim.time, closeTo(0.002, 1e-10));
    },
  );

  // 单步后的 geom 世界位姿应与同一时刻 qpos 的运动学一致。
  test('Geom world poses match pendulum kinematics after a step', () {
    sim.reset(demoPose: true);
    sim.singleStep();
    final angle = sim.data.qpos[0];
    final position = sim.geomPosition(4); // Pendulum bob.
    expect(position[0], closeTo(-1 - 1.1 * math.sin(angle), 1e-10));
    expect(position[2], closeTo(2 - 1.1 * math.cos(angle), 1e-10));
  });

  // 行主序的 MuJoCo 旋转转为列主序 Scene 矩阵，并仅在根节点转换 Z-up。
  test('Geom matrix preserves rotation and maps Z up into viewer Y up', () {
    final matrix = geomTransform([1, 2, 3], [0, -1, 0, 1, 0, 0, 0, 0, 1]);
    final p = matrix.transform3(vm.Vector3(1, 0, 0));
    expect(p.x, closeTo(1, 1e-12));
    expect(p.y, closeTo(3, 1e-12));
    expect(p.z, closeTo(3, 1e-12));
    final root = vm.Matrix4.rotationX(-math.pi / 2);
    final expected = viewerPosition([p.x, p.y, p.z]);
    final converted = root.transform3(p);
    expect((converted - expected).length, lessThan(1e-12));
  });

  // 仿真可运行不代表移除了 Python，直接检查进程映射确保未加载解释器。
  test('Native simulation does not load the Python interpreter', () {
    sim.singleStep();
    if (Platform.isLinux) {
      expect(
        File('/proc/self/maps').readAsStringSync(),
        isNot(contains('libpython')),
      );
    }
  });

  test('Invalid XML fails without leaking an owned model', () {
    expect(
      () => MujocoSimulation.xml('<mujoco><bad/></mujoco>'),
      throwsFormatException,
    );
    sim.singleStep();
    expect(sim.time, greaterThan(0));
  });
}
