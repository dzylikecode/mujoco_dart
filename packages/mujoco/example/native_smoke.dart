import 'package:mujoco/mujoco.dart';

void main() {
  final spec = mj_parseXMLString('''<mujoco>
  <asset><mesh name="tetrahedron" vertex="0 0 0  0.1 0 0  0 0.1 0  0 0 0.1"/></asset>
  <worldbody><body name="body" pos="0 0 1"><freejoint/>
    <geom type="mesh" mesh="tetrahedron" mass="1"/>
  </body></worldbody>
</mujoco>''');
  late final MjModel model;
  try {
    model = mj_compile(spec);
  } finally {
    spec.dispose();
  }
  MjData? data;
  try {
    data = MjData(model);
    final initialTime = data.time;
    mj_step(model, data);
    if (data.time <= initialTime) {
      throw StateError('MuJoCo did not advance the simulation');
    }
    print('MuJoCo ${Mujoco.version}: mesh compilation and simulation passed');
  } finally {
    data?.dispose();
    model.dispose();
  }
}
