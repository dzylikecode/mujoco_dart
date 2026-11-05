import 'package:mujoco/mujoco.dart';
import 'package:test/test.dart';

void main() {
  test('Compiled plane material exposes copied checker pixels, roles and repeat settings', () {
    final model = MjModel.from_xml_string(
      '''<mujoco><asset>
      <texture name="sky" type="skybox" builtin="gradient" rgb1="0 0 0" rgb2="1 1 1" width="4" height="4"/>
      <texture name="checker" type="2d" builtin="checker" width="8" height="8"
        rgb1="1 0 0" rgb2="0 0 1" mark="cross" markrgb="1 1 1"/>
      <material name="floor" texture="checker" texrepeat="2 3" texuniform="true" rgba=".2 .4 .6 1"/>
      </asset><worldbody><geom type="plane" size="2 3 .1" material="floor"/></worldbody></mujoco>''',
    );
    try {
      expect(model.ntex, 2);
      final floor = model.geomById(0);
      expect(floor.colorTextureId, 1);
      expect(floor.textureRepeat, [2, 3]);
      expect(floor.textureUniform, isTrue);
      expect(
        floor.rgba,
        orderedEquals([
          closeTo(.2, 1e-6),
          closeTo(.4, 1e-6),
          closeTo(.6, 1e-6),
          1,
        ]),
      );
      final texture = model.textureById(floor.colorTextureId);
      expect(texture.type, MjTextureType.twoD);
      expect(texture.colorSpace, MjTextureColorSpace.linear);
      expect(texture.width, 8);
      expect(texture.height, 8);
      expect(texture.channels, 3);
      expect(texture.pixels.length, 8 * 8 * 3);
      final colors = <String>{};
      for (var i = 0; i < texture.pixels.length; i += 3) {
        colors.add(texture.pixels.sublist(i, i + 3).join(','));
      }
      expect(colors, containsAll(['255,0,0', '0,0,255', '255,255,255']));
      final original = texture.pixels[0];
      texture.pixels[0] = 17;
      expect(model.textureById(1).pixels[0], original);
      expect(() => model.textureById(2), throwsRangeError);
      model.dispose();
      expect(texture.pixels[0], 17);
      expect(() => model.textureById(1), throwsStateError);
    } finally {
      model.dispose();
    }
  });

  test('A plain colored floor has no texture and keeps its authored color', () {
    final model = MjModel.from_xml_string(
      '''<mujoco><asset>
      <material name="floor" rgba=".2 .4 .6 1"/>
      </asset><worldbody><geom type="plane" size="1 1 .1" material="floor" rgba="1 0 0 1"/></worldbody></mujoco>''',
    );
    try {
      final floor = model.geomById(0);
      expect(floor.colorTextureId, -1);
      expect(floor.rgba, [1, 0, 0, 1]);
      expect(model.ntex, 0);
    } finally {
      model.dispose();
    }
  });
}
