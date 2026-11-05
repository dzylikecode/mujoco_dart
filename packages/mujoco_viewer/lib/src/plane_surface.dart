import 'dart:math' as math;
import 'dart:typed_data';

import 'package:mujoco/mujoco.dart';
import 'package:vector_math/vector_math.dart' as vm;

// Matches MuJoCo 3.12's classic plane UVs and texture-matrix scaling.
({Float32List positions, Float32List normals, Float32List texCoords})
planeSurface(MjGeomInfo geom, {required double infiniteHalfExtent}) {
  final sx = geom.size[0], sy = geom.size[1];
  final hx = sx > 0 ? sx : infiniteHalfExtent;
  final hy = sy > 0 ? sy : infiniteHalfExtent;
  final infinite = sx <= 0 || sy <= 0;
  final repeat = geom.textureRepeat;
  final scaleX =
      (repeat[0] > 0 ? repeat[0] : 1) *
      (geom.textureUniform && sx > 0 ? sx : 1);
  final scaleY =
      (repeat[1] > 0 ? repeat[1] : 1) *
      (geom.textureUniform && sy > 0 ? sy : 1);
  final positions = Float32List.fromList([
    -hx,
    -hy,
    0,
    hx,
    -hy,
    0,
    hx,
    hy,
    0,
    -hx,
    -hy,
    0,
    hx,
    hy,
    0,
    -hx,
    hy,
    0,
  ]);
  final normals = Float32List(18);
  final uvs = Float32List(12);
  for (var i = 0; i < 6; i++) {
    final x = positions[i * 3], y = positions[i * 3 + 1];
    final u = sx > 0 ? (x + sx) / (2 * sx) : 0.5 * x;
    final v = sy > 0 ? 1 - (y + sy) / (2 * sy) : -0.5 * y;
    uvs[i * 2] = u * scaleX - (infinite ? 0.5 : 0);
    uvs[i * 2 + 1] = v * scaleY - (infinite ? 0.5 : 0);
    normals[i * 3 + 2] = 1;
  }
  return (positions: positions, normals: normals, texCoords: uvs);
}

final _linearToSrgb = List<int>.generate(256, (value) {
  final linear = value / 255;
  final encoded = linear <= 0.0031308
      ? linear * 12.92
      : 1.055 * math.pow(linear, 1 / 2.4) - 0.055;
  return (encoded * 255).round().clamp(0, 255);
});

// Scene's color shader decodes sRGB, so encode linear MuJoCo textures first.
Uint8List textureRgba(MjTextureInfo texture) {
  if (texture.channels < 1 || texture.channels > 4) {
    throw FormatException(
      'Unsupported texture channel count: ${texture.channels}',
    );
  }
  final count = texture.width * texture.height;
  final pixels = texture.pixels;
  final rgba = Uint8List(count * 4);
  final gray = texture.channels < 3;
  for (var i = 0; i < count; i++) {
    final source = i * texture.channels;
    for (var c = 0; c < 3; c++) {
      final value = pixels[source + (gray ? 0 : c)];
      rgba[i * 4 + c] = texture.colorSpace == MjTextureColorSpace.srgb
          ? value
          : _linearToSrgb[value];
    }
    rgba[i * 4 + 3] = switch (texture.channels) {
      2 => pixels[source + 1],
      4 => pixels[source + 3],
      _ => 255,
    };
  }
  return rgba;
}

// Bounds every point in a finite camera frustum, including wide and orthographic
// views. Scene camera projections use depth 0..1 before renderer adjustments.
double projectionReach(vm.Matrix4 projection) {
  final inverse = vm.Matrix4.copy(projection);
  if (inverse.invert() == 0) {
    throw ArgumentError('Camera projection is singular');
  }
  var reach = 0.0;
  for (final x in [-1.0, 1.0]) {
    for (final y in [-1.0, 1.0]) {
      for (final z in [0.0, 1.0]) {
        final point = inverse.transform(vm.Vector4(x, y, z, 1));
        final distance =
            math.sqrt(
              point.x * point.x + point.y * point.y + point.z * point.z,
            ) /
            point.w.abs();
        if (!distance.isFinite) {
          throw ArgumentError('Camera needs a finite far clip');
        }
        reach = math.max(reach, distance);
      }
    }
  }
  return reach;
}

// MuJoCo snaps the visual center by 2 * (2 / texrepeat). Two complete repeats
// preserve the sampled texture phase while the finite patch follows the eye.
({vm.Vector3 center, double halfExtent}) infinitePlanePlacement(
  MjGeomInfo geom,
  vm.Vector3 localEye, {
  required double viewReach,
}) {
  final center = vm.Vector3.zero();
  var margin = 0.0;
  for (var axis = 0; axis < 2; axis++) {
    if (geom.size[axis] > 0) continue;
    final repeat = geom.textureRepeat[axis];
    final step = repeat > 0 ? 4 / repeat : 4.0;
    center[axis] = (localEye[axis] / step).roundToDouble() * step;
    margin = math.max(margin, step * 0.5);
  }
  return (center: center, halfExtent: viewReach * 1.05 + margin);
}
