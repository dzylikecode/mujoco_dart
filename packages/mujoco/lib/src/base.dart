// ignore_for_file: non_constant_identifier_names

import 'dart:typed_data';

import 'backend/native.dart'
    if (dart.library.js_interop) 'backend/web.dart'
    as platform;
import 'model_info.dart';

import 'package:meta/meta.dart';

@internal
BaseApi get api => platform.api;

abstract final class Mujoco {
  static String get version => api.version;
}

void _checkPair(MjModel model, MjData data) {
  if (model.isDisposed || data.isDisposed) {
    throw StateError('Model or data is disposed');
  }
  if (!identical(model, data.model)) {
    throw ArgumentError('Data belongs to a different model');
  }
}

void mj_forward(MjModel model, MjData data) {
  _checkPair(model, data);
  api.mj_forward(model, data);
}

void mj_step(MjModel model, MjData data) {
  _checkPair(model, data);
  api.mj_step(model, data);
}

void mj_resetData(MjModel model, MjData data) {
  _checkPair(model, data);
  api.mj_resetData(model, data);
}

/// Loads and compiles an XML file using MuJoCo's platform file system or [vfs].
///
/// The caller owns the returned model. The VFS is borrowed only for this call.
/// On web, download URL resources into a VFS before loading their virtual paths.
/// Missing VFS files may fall back to MuJoCo's platform file system.
/// Throws [FormatException] on parse or compilation failure.
MjModel mj_loadXML(String filename, {MjVfs? vfs}) {
  _checkVfs(vfs);
  return api.mj_loadXML(filename, vfs: vfs);
}

/// Parses XML into an owned, uncompiled specification.
///
/// Resolves includes through [vfs]. Pass the asset VFS again to [mj_compile]
/// when compilation needs meshes or textures. Neither call owns the VFS.
/// Throws [FormatException] on parse failure.
MjSpec mj_parseXMLString(String xml, {MjVfs? vfs}) {
  _checkVfs(vfs);
  return api.mj_parseXMLString(xml, vfs: vfs);
}

/// Compiles [spec] into an independently owned model.
///
/// The caller retains ownership of [spec] and [vfs], which may be released
/// after this call or reused for another compilation.
/// Throws [FormatException] on compilation failure and [StateError] if an
/// input resource is disposed.
MjModel mj_compile(MjSpec spec, {MjVfs? vfs}) {
  if (spec.isDisposed) throw StateError('Spec is disposed');
  _checkVfs(vfs);
  return api.mj_compile(spec, vfs: vfs);
}

void _checkVfs(MjVfs? vfs) {
  if (vfs != null && vfs.isDisposed) throw StateError('VFS is disposed');
}

/// An owned MuJoCo model specification, separate from a compiled [MjModel].
///
/// Created by [mj_parseXMLString] and compiled by [mj_compile].
abstract interface class MjSpec {
  /// Whether this specification has been released.
  bool get isDisposed;

  /// Releases this specification without releasing any compiled models.
  ///
  /// Repeated calls are safe. Compiling a disposed spec throws [StateError].
  void dispose();
}

@internal
abstract interface class BaseApi {
  String get version;
  MjData MjData_new(MjModel model);
  MjVfs MjVfs_new();
  MjSpec mj_parseXMLString(String xml, {MjVfs? vfs});
  MjModel mj_compile(MjSpec spec, {MjVfs? vfs});
  MjModel mj_loadXML(String filename, {MjVfs? vfs});
  void mj_forward(MjModel model, MjData data);
  void mj_step(MjModel model, MjData data);
  void mj_resetData(MjModel model, MjData data);
}

abstract interface class MjData {
  factory(MjModel model) => api.MjData_new(model);

  MjModel get model;

  /// Looks up a body's world position and applied wrench by name.
  MjDataBodyViews body(String name);

  /// Looks up body data by ID, including world body zero.
  MjDataBodyViews bodyById(int id);

  double get time;
  int get ncon;
  MjDoubleListView geomPosition(int id);
  MjDoubleListView geomRotation(int id);

  MjDoubleListView get qpos;
  MjDoubleListView get qvel;
  MjDoubleListView get qacc;
  MjDoubleListView get act;
  MjDoubleListView get ctrl;

  /// 存放所有的传感器数据
  ///
  /// 原本二维的数据表被展平成一维数组
  ///
  /// ```txt
  /// sensor1: [0, 1, 2, 3]
  /// sensor2: [4, 5, 6]
  /// sensor3: [7, 8]
  /// ```
  ///
  /// 然后被展平成一维数组
  ///
  /// ```txt
  /// sensordata: [0, 1, 2, 3, 4, 5, 6, 7, 8]
  /// ```
  ///
  /// 通过 [adr, adr + ndim) 来访问
  MjDoubleListView get sensordata;

  /// Looks up a sensor by name.
  /// The returned view is valid until this data or its model is disposed.
  MjDataSensorViews sensor(String name);

  /// Looks up a sensor by ID, with the same lifetime as [sensor].
  MjDataSensorViews sensorById(int id);

  bool get isDisposed;

  void dispose();
}

/// An owned in-memory file system for model XML and referenced assets.
///
/// Native and web use MuJoCo's VFS, not the browser's global file system.
/// Files are copied when added. Compiled models do not retain this resource,
/// so it may be reused for multiple loads or disposed after compilation.
abstract interface class MjVfs {
  factory() => api.MjVfs_new();

  /// Copies [bytes] into a file named [filename].
  ///
  /// Paths follow MuJoCo's VFS lookup rules. Delete an existing file before
  /// adding its replacement. Throws [StateError] if the file cannot be added.
  void addBuffer(String filename, Uint8List bytes);

  /// Deletes the file named [filename].
  ///
  /// Does nothing if the file does not exist.
  void deleteFile(String filename);

  /// Whether this file system has been released.
  bool get isDisposed;

  /// Releases all files and the underlying native or WASM resource.
  ///
  /// Repeated calls are safe. Other operations throw [StateError] afterwards.
  void dispose();
}

/// An owned compiled model created by [mj_loadXML] or [mj_compile].
abstract interface class MjModel {
  /// Parses and compiles XML, borrowing [vfs] for includes and assets.
  ///
  /// Releases the intermediate [MjSpec] before returning the owned model.
  /// Use [mj_parseXMLString] and [mj_compile] to manage that spec explicitly.
  factory from_xml_string(String xml, {MjVfs? vfs}) {
    final spec = mj_parseXMLString(xml, vfs: vfs);
    try {
      return mj_compile(spec, vfs: vfs);
    } finally {
      spec.dispose();
    }
  }

  /// Loads and compiles a file through [mj_loadXML], borrowing [vfs].
  factory from_xml_path(String path, {MjVfs? vfs}) =>
      mj_loadXML(path, vfs: vfs);

  int get ngeom;
  int get nmesh;

  /// The number of compiled texture assets.
  int get ntex;

  /// Copies a compiled texture, including builtin checker and file textures.
  MjTextureInfo textureById(int id);
  List<double> get center;
  double get extent;
  MjGeomInfo geomById(int id);
  MjMeshInfo meshById(int id);

  /// The physics timestep in seconds.
  double get timestep;

  /// The number of joints in the compiled model.
  int get njnt;

  /// The number of bodies, including the world body.
  int get nbody;

  /// Returns a snapshot of joint metadata by ID.
  MjJointInfo jointById(int id);

  /// Returns a snapshot of actuator metadata by ID.
  MjActuatorInfo actuatorById(int id);

  /// Returns a body's metadata by name.
  MjBodyInfo body(String name);

  /// Returns a body's metadata by ID.
  MjBodyInfo bodyById(int id);

  /// Number of generalized position coordinates in [MjData.qpos].
  int get nq;

  /// Number of degrees of freedom in [MjData.qvel] and [MjData.qacc].
  int get nv;

  /// Number of actuator control inputs in [MjData.ctrl].
  int get nu;

  /// Number of actuator activation states in [MjData.act].
  int get na;

  /// Number of sensors in the model.
  int get nsensor;

  /// Total number of scalar sensor readings in [MjData.sensordata].
  int get nsensordata;

  /// Looks up a sensor by name.
  /// The returned view is valid until this model is disposed.
  MjModelSensorViews sensor(String name);

  /// Looks up a sensor by ID, with the same lifetime as [sensor].
  MjModelSensorViews sensorById(int id);

  bool get isDisposed;

  void dispose();
}

abstract interface class MjDoubleListView {
  int get length;
  double operator [](int index);
  void operator []=(int index, double value);
  List<double> toList();
}

/// Configuration of one sensor in a compiled model.
abstract interface class MjModelSensorViews {
  int get id;
  String get name;
  int get type;

  /// The sensor's meaning independent of backend-specific enum numbering.
  MjSensorKind get kind;
  int get dim;
  int get adr;
}

/// Current readings of one sensor, backed by the data's sensor buffer.
abstract interface class MjDataSensorViews {
  int get id;
  String get name;
  MjDoubleListView get data;
}

/// Live body data with the lifetime of its owning model and data.
abstract interface class MjDataBodyViews {
  int get id;
  String get name;

  /// The body frame's world position, in metres.
  MjDoubleListView get position;

  /// The applied world-frame wrench: force xyz followed by torque xyz.
  ///
  /// This maps to MuJoCo's `xfrc_applied` at the body's centre of mass.
  MjDoubleListView get appliedForce;
}

/// Bounded bulk operations shared by both backends.
extension MjDoubleListOperations on MjDoubleListView {
  /// Copies values beginning at [index], following Dart List semantics.
  void setAll(int index, Iterable<double> values) {
    final copy = values.toList(growable: false);
    RangeError.checkValidRange(index, index + copy.length, length);
    for (var i = 0; i < copy.length; i++) {
      this[index + i] = copy[i];
    }
  }

  /// Fills the half-open interval with [value].
  void fillRange(int start, int end, double value) {
    RangeError.checkValidRange(start, end, length);
    for (var i = start; i < end; i++) {
      this[i] = value;
    }
  }
}
