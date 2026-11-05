import 'dart:typed_data';

import 'base.dart';

/// An owned, immutable snapshot of MuJoCo geom world poses in Z-up coordinates.
///
/// Positions are packed XYZ triples; rotations are packed row-major 3x3 matrices.
/// A snapshot contains no native pointers and may outlive its source data/model.
class MjSceneState {
  MjSceneState({
    required this.time,
    required List<double> positions,
    required List<double> rotations,
  }) : positions = Float64List.fromList(positions).asUnmodifiableView(),
       rotations = Float64List.fromList(rotations).asUnmodifiableView() {
    if (!time.isFinite ||
        positions.length % 3 != 0 ||
        rotations.length != positions.length * 3 ||
        positions.any((v) => !v.isFinite) ||
        rotations.any((v) => !v.isFinite)) {
      throw ArgumentError(
        'Expected finite time and matching XYZ/3x3 geom poses',
      );
    }
  }

  /// Copies the current compiled geom poses. Run mj_forward after editing qpos.
  factory MjSceneState.fromData(MjData data) {
    final count = data.model.ngeom;
    final positions = Float64List(count * 3);
    final rotations = Float64List(count * 9);
    for (var i = 0; i < count; i++) {
      positions.setRange(i * 3, i * 3 + 3, data.geomPosition(i).toList());
      rotations.setRange(i * 9, i * 9 + 9, data.geomRotation(i).toList());
    }
    return MjSceneState(
      time: data.time,
      positions: positions,
      rotations: rotations,
    );
  }

  final double time;
  final Float64List positions;
  final Float64List rotations;
  int get geomCount => positions.length ~/ 3;
}
