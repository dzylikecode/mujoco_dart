import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mujoco/mujoco.dart';
import 'package:mujoco_viewer/src/plane_surface.dart';

MjGeomInfo floor({
  List<double> size = const [2, 3, .1],
  bool uniform = false,
}) => MjGeomInfo(
  id: 0,
  name: 'floor',
  type: 0,
  group: 0,
  size: size,
  rgba: const [1, 1, 1, 1],
  metallic: 0,
  roughness: 1,
  meshId: -1,
  materialId: 0,
  textureRepeat: const [2, 4],
  textureUniform: uniform,
);

void main() {
  test(
    'Plane vertices stay exactly on the collision surface with upward winding',
    () {
      final surface = planeSurface(floor(), infiniteHalfExtent: 20);
      for (var i = 0; i < 6; i++) {
        expect(surface.positions[i * 3 + 2], 0);
        expect(surface.normals.sublist(i * 3, i * 3 + 3), [0, 0, 1]);
      }
      final p = surface.positions;
      final crossZ =
          (p[3] - p[0]) * (p[7] - p[1]) - (p[4] - p[1]) * (p[6] - p[0]);
      expect(crossZ, greaterThan(0));
    },
  );

  test('Finite plane UVs match MuJoCo object-relative and uniform scaling', () {
    final relative = planeSurface(floor(), infiniteHalfExtent: 20).texCoords;
    expect(relative.sublist(0, 6), [0, 4, 2, 4, 2, 0]);
    final uniform = planeSurface(
      floor(uniform: true),
      infiniteHalfExtent: 20,
    ).texCoords;
    expect(uniform.sublist(0, 6), [0, 12, 4, 12, 4, 0]);
  });

  test(
    'Infinite plane UVs remain in spatial units when the visible patch changes',
    () {
      final small = planeSurface(
        floor(size: [0, 0, .1], uniform: true),
        infiniteHalfExtent: 5,
      );
      final large = planeSurface(
        floor(size: [0, 0, .1], uniform: true),
        infiniteHalfExtent: 10,
      );
      expect(small.texCoords.sublist(0, 2), [-5.5, 9.5]);
      final smallSlope =
          (small.texCoords[2] - small.texCoords[0]) /
          (small.positions[3] - small.positions[0]);
      final largeSlope =
          (large.texCoords[2] - large.texCoords[0]) /
          (large.positions[3] - large.positions[0]);
      expect(smallSlope, largeSlope);
    },
  );

  test('Texture expansion preserves sRGB alpha and encodes linear colors for Scene', () {
    MjTextureInfo texture(
      List<int> pixels,
      int channels,
      MjTextureColorSpace colorSpace,
    ) => MjTextureInfo(
      id: 0,
      type: MjTextureType.twoD,
      colorSpace: colorSpace,
      width: pixels.length ~/ channels,
      height: 1,
      channels: channels,
      pixels: Uint8List.fromList(pixels),
    );
    expect(textureRgba(texture([128, 64], 1, MjTextureColorSpace.linear)), [
      188,
      188,
      188,
      255,
      137,
      137,
      137,
      255,
    ]);
    expect(
      textureRgba(texture([12, 34, 56, 78], 4, MjTextureColorSpace.srgb)),
      [12, 34, 56, 78],
    );
    expect(textureRgba(texture([128, 33], 2, MjTextureColorSpace.srgb)), [
      128,
      128,
      128,
      33,
    ]);
    expect(textureRgba(texture([1, 2, 3], 3, MjTextureColorSpace.srgb)), [
      1,
      2,
      3,
      255,
    ]);
  });
}
