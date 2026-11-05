import 'dart:typed_data';

/// The four joint types defined by MuJoCo.
enum MjJointType { free, ball, slide, hinge }

/// Sensor meanings independent of the implementation's enum numbering.
enum MjSensorKind { accelerometer, gyro, frameQuaternion, other }

/// A snapshot of joint addresses in the compiled model.
class const MjJointInfo({
  required final int id,
  required final String name,
  required final MjJointType type,
  required final int qposAddress,
  required final int dofAddress,
});

/// A snapshot of actuator transmission and control metadata.
class const MjActuatorInfo({
  required final int id,
  required final String name,
  required final MjJointInfo? joint,
  required final bool isUnitTorqueMotor,
  required final ({double lower, double upper})? controlRange,
});

/// A snapshot identifying a body in the compiled model.
class const MjBodyInfo(final int id, final String name);

/// Compiled geometry metadata shared by native and JavaScript backends.
class MjGeomInfo {
  const MjGeomInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.group,
    required this.size,
    required this.rgba,
    required this.metallic,
    required this.roughness,
    required this.meshId,
    required this.materialId,
  });
  final int id, type, group, meshId, materialId;
  final String name;
  final List<double> size, rgba;
  final double metallic, roughness;
}

/// Compiled mesh triangles in the owning geom frame, with per-corner normals.
class MjMeshInfo {
  const MjMeshInfo(this.positions, this.normals);
  final Float32List positions, normals;
  int get triangleCount => positions.length ~/ 9;
}
