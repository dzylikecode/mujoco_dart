import 'dart:io';

import 'package:flutter_scene_lab/simulation.dart';

void main(List<String> args) {
  final sim = args.isEmpty
      ? MujocoSimulation.xml(File('assets/physics_lab.xml').readAsStringSync())
      : MujocoSimulation.path(File(args.first).absolute.path);
  try {
    final watch = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      sim.singleStep();
    }
    watch.stop();
    if (!sim.time.isFinite || sim.time <= 0) {
      throw StateError('Simulation did not advance');
    }
    final pythonLoaded =
        Platform.isLinux &&
        File('/proc/self/maps').readAsStringSync().contains('libpython');
    if (pythonLoaded) {
      throw StateError('Python interpreter unexpectedly loaded');
    }
    stdout.writeln(
      'MuJoCo ${sim.version}: ${sim.model.nq} qpos, ${sim.geomCount} geoms, '
      '${sim.model.nmesh} meshes; t=${sim.time}, contacts=${sim.contacts}; '
      '1000 steps + forward: ${watch.elapsedMilliseconds} ms; libpython loaded: $pythonLoaded',
    );
  } finally {
    sim.dispose();
  }
}
