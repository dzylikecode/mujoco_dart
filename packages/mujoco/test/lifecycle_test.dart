import 'package:mujoco/mujoco.dart';
import 'package:test/test.dart';

import 'model_fixture.dart';

const xml = '''
<mujoco><worldbody><body name="body"><joint name="hinge" type="hinge"/>
<geom type="sphere" size="0.1" mass="1"/></body></worldbody>
<sensor><jointpos name="angle" joint="hinge"/></sensor></mujoco>
''';

void main() {
  test('Explicit disposal is idempotent for data and model', () {
    final model = compileXml(xml);
    final data = MjData(model);
    try {
      data.qpos[0] = 0.4;
      mj_forward(model, data);
      expect(data.sensor('angle').data[0], closeTo(0.4, 1e-12));
      data.dispose();
      data.dispose();
      expect(data.isDisposed, isTrue);
      expect(model.isDisposed, isFalse);
      model.dispose();
      model.dispose();
      expect(model.isDisposed, isTrue);
    } finally {
      data.dispose();
      model.dispose();
    }
  });

  test('Disposing data leaves its model usable by another data owner', () {
    final model = compileXml(xml);
    final first = MjData(model);
    try {
      first.qpos[0] = 0.7;
      first.dispose();
      final second = MjData(model);
      try {
        expect(second.qpos[0], 0);
        mj_step(model, second);
        expect(second.time, greaterThan(0));
        expect(() => first.qpos[0], throwsStateError);
      } finally {
        second.dispose();
      }
    } finally {
      first.dispose();
      model.dispose();
    }
  });

  test('All borrowed views reject access after data disposal', () {
    final model = compileXml(xml);
    final data = MjData(model);
    try {
      mj_forward(model, data);
      final views = [
        data.qpos,
        data.sensor('angle').data,
        data.geomPosition(0),
        data.geomRotation(0),
        data.body('body').position,
        data.body('body').appliedForce,
      ];
      data.dispose();
      for (final view in views) {
        expect(() => view.length, throwsStateError);
        expect(view.toList, throwsStateError);
        expect(() => view[0], throwsStateError);
        expect(() => view[0] = 1, throwsStateError);
      }
      expect(() => data.qvel.toList(), throwsStateError);
    } finally {
      data.dispose();
      model.dispose();
    }
  });

  test('Model disposal invalidates live data views and physics operations', () {
    final model = compileXml(xml);
    final data = MjData(model);
    final qpos = data.qpos;
    final sensor = model.sensor('angle');
    try {
      model.dispose();
      expect(() => qpos[0], throwsStateError);
      expect(() => sensor.dim, throwsStateError);
      expect(() => mj_step(model, data), throwsStateError);
      expect(() => model.nq, throwsStateError);
      data.dispose();
      expect(data.isDisposed, isTrue);
    } finally {
      data.dispose();
      model.dispose();
    }
  });

  test('A disposed model cannot allocate a new data owner', () {
    final model = compileXml(xml);
    model.dispose();
    expect(() => MjData(model), throwsStateError);
    model.dispose();
  });
}
