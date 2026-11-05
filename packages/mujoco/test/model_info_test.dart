import 'package:mujoco/mujoco.dart';
import 'package:test/test.dart';

import 'model_fixture.dart';

const xml = '''
<mujoco>
  <option timestep="0.002" gravity="0 0 0"/>
  <worldbody><body name="base_link" pos="0 0 1"><freejoint/>
    <geom type="sphere" size="0.1" mass="1"/><site name="imu"/>
    <body name="first"><joint name="first_joint" type="hinge"/>
      <geom type="sphere" size="0.05" mass="1"/>
      <body name="second"><joint name="second_joint" type="hinge"/>
        <geom type="sphere" size="0.04" mass="1"/>
      </body>
    </body>
  </body></worldbody>
  <actuator>
    <motor name="torque" joint="second_joint" ctrllimited="true" ctrlrange="-3 4"/>
    <motor name="geared" joint="first_joint" gear="2"/>
    <position name="servo" joint="first_joint" kp="10"/>
  </actuator>
  <sensor>
    <framequat name="orientation" objtype="body" objname="base_link"/>
    <gyro name="angular-velocity" site="imu"/>
    <accelerometer name="linear-acceleration" site="imu"/>
  </sensor>
</mujoco>
''';

void main() {
  for (final backend in ['native']) {
    group(backend, () {
      late MjModel model;
      late MjData data;
      setUp(() {
        model = compileXml(xml);
        data = MjData(model);
        mj_forward(model, data);
      });
      tearDown(() {
        data.dispose();
        model.dispose();
      });
      test('public metadata resolves actuator order and motor semantics', () {
        expect(model.timestep, 0.002);
        final motor = model.actuatorById(0);
        expect(motor.name, 'torque');
        expect(motor.joint!.name, 'second_joint');
        expect(motor.joint!.qposAddress, 8);
        expect(motor.joint!.dofAddress, 7);
        expect(motor.joint!.type, MjJointType.hinge);
        expect(motor.isUnitTorqueMotor, isTrue);
        expect(motor.controlRange, (lower: -3.0, upper: 4.0));
        expect(model.actuatorById(1).isUnitTorqueMotor, isFalse);
        expect(model.actuatorById(1).controlRange, isNull);
        expect(model.actuatorById(2).isUnitTorqueMotor, isFalse);
        expect(model.sensor('orientation').kind, MjSensorKind.frameQuaternion);
        expect(() => model.actuatorById(3), throwsRangeError);
        expect(() => model.body('absent'), throwsArgumentError);
      });
      test('body wrench is live, bounded and changes physics', () {
        final body = data.body('base_link');
        expect(body.position.toList(), [0, 0, 1]);
        expect(body.appliedForce.length, 6);
        body.appliedForce.setAll(0, [0, 0, 30, 0, 0, 0]);
        for (var i = 0; i < 10; i++) {
          mj_step(model, data);
        }
        mj_forward(model, data);
        expect(body.position[2], greaterThan(1));
        body.appliedForce.fillRange(0, 6, 0);
        expect(body.appliedForce.toList(), everyElement(0));
        expect(() => body.appliedForce[6], throwsRangeError);
        expect(() => body.position.setAll(2, [1, 2]), throwsRangeError);
        final retained = body.appliedForce;
        data.dispose();
        expect(() => retained[0], throwsStateError);
        expect(() => data.bodyById(0), throwsStateError);
      });
      test('selected api steps and resets simulation data', () {
        mj_step(model, data);
        expect(data.time, closeTo(0.002, 1e-12));
        mj_resetData(model, data);
        expect(data.time, 0);
      });
    });
  }
}
