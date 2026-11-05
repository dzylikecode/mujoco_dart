import 'dart:typed_data';

import 'package:mujoco/mujoco.dart' as mj;

// Fixed-step simulation convenience; independent of Flutter rendering.
class MujocoSimulation {
  MujocoSimulation._(this.model) {
    data = mj.MjData(model);
    mj.mj_forward(model, data);
  }

  factory MujocoSimulation.xml(String xml) =>
      MujocoSimulation._(mj.MjModel.from_xml_string(xml));

  factory MujocoSimulation.path(String path) =>
      MujocoSimulation._(mj.MjModel.from_xml_path(path));

  factory MujocoSimulation.model(mj.MjModel model) => MujocoSimulation._(model);

  final mj.MjModel model;
  late final mj.MjData data;
  bool _disposed = false;
  double _accumulator = 0;
  double speed = 1;
  double motor = 0;
  int steps = 0;
  int get geomCount => model.ngeom;
  int get contacts => data.ncon;
  double get time => data.time;
  double get timestep => model.timestep;
  String get version => mj.Mujoco.version;

  void advance(double seconds) {
    // Cap catch-up work so an overloaded UI does not enter a spiral of death.
    // Paused wall time is never accumulated. Slow machines run slower than real time.
    _accumulator += seconds.clamp(0.0, 0.05) * speed;
    var count = 0;
    while (_accumulator >= timestep && count < 100) {
      _step();
      _accumulator -= timestep;
      count++;
    }
    if (count == 100) _accumulator = 0;
    if (count > 0) mj.mj_forward(model, data);
  }

  void _step() {
    if (model.nu > 0) data.ctrl[0] = motor;
    mj.mj_step(model, data);
    steps++;
  }

  void singleStep() {
    _step();
    // mj_step integrates qpos after computing geom poses; refresh them so the
    // viewer and qpos refer to the same instant, including while paused.
    mj.mj_forward(model, data);
  }

  void reset({bool demoPose = false}) {
    mj.mj_resetData(model, data);
    if (demoPose && model.nq > 0) data.qpos[0] = 0.75;
    steps = 0;
    _accumulator = 0;
    mj.mj_forward(model, data);
  }

  void kick() {
    if (model.nv > 0) data.qvel[0] += 2;
    mj.mj_forward(model, data);
  }

  String geomName(int id) => model.geomById(id).name;
  Float64List geomPosition(int id) =>
      Float64List.fromList(data.geomPosition(id).toList());
  Float64List geomRotation(int id) =>
      Float64List.fromList(data.geomRotation(id).toList());

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    data.dispose();
    model.dispose();
  }
}
