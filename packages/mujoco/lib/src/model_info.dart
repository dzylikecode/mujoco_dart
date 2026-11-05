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
    this.colorTextureId = -1,
    this.textureRepeat = const [1, 1],
    this.textureUniform = false,
  });
  final int id, type, group, meshId, materialId;
  final String name;
  final List<double> size, rgba;
  final double metallic, roughness;

  /// The base-color texture index, or -1 when no texture is assigned.
  final int colorTextureId;

  /// The material's two-dimensional texture repetition factors.
  final List<double> textureRepeat;

  /// Whether texture repetition is relative to spatial units.
  final bool textureUniform;
}

/// Compiled mesh triangles in the owning geom frame, with per-corner normals.
class MjMeshInfo {
  const MjMeshInfo(this.positions, this.normals);
  final Float32List positions, normals;
  int get triangleCount => positions.length ~/ 9;
}

/// The texture layouts used by MuJoCo.
enum MjTextureType { twoD, cube, skybox }

/// The color encoding of compiled texture pixels.
enum MjTextureColorSpace { linear, srgb }

/// A copied snapshot of compiled texture pixels and their layout.
///
/// Pixels retain MuJoCo's row order and channel count. The snapshot owns no
/// engine memory and remains readable after model disposal.
class const MjTextureInfo({
  required final int id,
  required final MjTextureType type,
  required final MjTextureColorSpace colorSpace,
  required final int width,
  required final int height,
  required final int channels,
  required final Uint8List pixels,
});
