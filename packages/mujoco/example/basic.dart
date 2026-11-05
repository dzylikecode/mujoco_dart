import 'package:mujoco/mujoco.dart';
import 'package:args/args.dart';

const xml = """
<mujoco model="basic_pendulum">
  <option timestep="0.002" gravity="0 0 -9.81"/>

  <worldbody>
    <geom name="floor" type="plane" size="2 2 0.1"/>

    <body name="pendulum" pos="0 0 1">
      <joint
        name="hinge"
        type="hinge"
        axis="0 1 0"
        damping="0.05"
      />
      <geom
        name="pole"
        type="capsule"
        fromto="0 0 0 0 0 -0.8"
        size="0.04"
        mass="1"
      />
    </body>
  </worldbody>

  <actuator>
    <motor name="hinge_motor" joint="hinge" gear="1"/>
  </actuator>
</mujoco>
""";

void main(List<String> arguments) {
  final ArgParser parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false);

  final args = parser.parse(arguments);

  if (args.flag('help')) {
    print(parser.usage);
    return;
  }

  print('MuJoCo ${Mujoco.version}');

  final spec = mj_parseXMLString(xml);
  late final MjModel model;
  try {
    model = mj_compile(spec);
  } finally {
    spec.dispose();
  }
  MjData? data;
  try {
    data = MjData(model);

    print('model nq: ${model.nq}, nv: ${model.nv}, nu: ${model.nu}');
    print(
      'qpos.length: ${data.qpos.length}, qvel.length: ${data.qvel.length}, act.length: ${data.act.length}, ctrl.length: ${data.ctrl.length}',
    );

    data.ctrl[0] = 1.0;

    for (var i = 0; i < 1000; i++) {
      mj_step(model, data);
      // print('time: ${data.time}, qpos: ${data.qpos.toList()}, qvel: ${data.qvel.toList()}, ctrl: ${data.ctrl.toList()}');
    }
  } finally {
    data?.dispose();
    model.dispose();
  }
}
