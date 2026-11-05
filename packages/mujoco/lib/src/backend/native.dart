// ignore_for_file: non_constant_identifier_names

import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart' as ffi;

import '../base.dart';
import '../model_info.dart';
import '../owner.dart';

import 'native.g.dart' as g;

final api = const NativeApi();

final class const NativeApi() implements BaseApi {
  @override
  String get version => g.mj_versionString().cast<ffi.Utf8>().toDartString();

  @override
  MjData MjData_new(covariant MjModelNative model) {
    if (model.isDisposed) throw StateError('Model is disposed');
    return MjDataNative(g.mj_makeData(model.ptr), model);
  }

  @override
  MjVfsNative MjVfs_new() => MjVfsNative();

  @override
  MjSpecNative mj_parseXMLString(String xml, {covariant MjVfsNative? vfs}) {
    vfs?._check();
    return ffi.using((arena) {
      const errorSize = 1024;
      final error = arena<Char>(errorSize);
      final spec = g.mj_parseXMLString(
        xml.toNativeUtf8(allocator: arena).cast<Char>(),
        vfs?.ptr ?? nullptr,
        error,
        errorSize,
      );
      if (spec == nullptr) {
        throw FormatException(error.cast<ffi.Utf8>().toDartString());
      }
      return MjSpecNative(spec);
    });
  }

  @override
  MjModelNative mj_compile(
    covariant MjSpecNative spec, {
    covariant MjVfsNative? vfs,
  }) {
    spec._check();
    vfs?._check();
    final model = g.mj_compile(spec.ptr, vfs?.ptr ?? nullptr);
    if (model == nullptr) {
      throw FormatException(
        g.mjs_getError(spec.ptr).cast<ffi.Utf8>().toDartString(),
      );
    }
    return MjModelNative(model);
  }

  @override
  MjModelNative mj_loadXML(String filename, {covariant MjVfsNative? vfs}) {
    vfs?._check();
    return ffi.using((arena) {
      const errorSize = 1024;
      final error = arena<Char>(errorSize);
      final model = g.mj_loadXML(
        filename.toNativeUtf8(allocator: arena).cast<Char>(),
        vfs?.ptr ?? nullptr,
        error,
        errorSize,
      );
      if (model == nullptr) {
        throw FormatException(error.cast<ffi.Utf8>().toDartString());
      }
      return MjModelNative(model);
    });
  }

  @override
  void mj_forward(covariant MjModelNative model, covariant MjDataNative data) =>
      g.mj_forward(model.ptr, data.ptr);

  @override
  void mj_step(covariant MjModelNative model, covariant MjDataNative data) =>
      g.mj_step(model.ptr, data.ptr);

  @override
  void mj_resetData(
    covariant MjModelNative model,
    covariant MjDataNative data,
  ) => g.mj_resetData(model.ptr, data.ptr);
}

/// Owns a MuJoCo virtual file system and its in-memory files.
class MjVfsNative._(final Pointer<g.mjVFS> ptr)
    with DisposableOwner
    implements MjVfs {
  this {
    g.mj_defaultVFS(ptr);
  }
  factory() => ._(ffi.calloc<g.mjVFS>());

  void _check() {
    if (isDisposed) throw StateError('VFS is disposed');
  }

  @override
  void addBuffer(String filename, Uint8List bytes) {
    _check();
    checkVfsFilename(filename);
    ffi.using((arena) {
      final buffer = arena<Uint8>(bytes.length);
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final result = g.mj_addBufferVFS(
        ptr,
        filename.toNativeUtf8(allocator: arena).cast<Char>(),
        buffer.cast<Void>(),
        bytes.length,
      );
      if (result != 0) {
        throw StateError(
          'Failed to add "$filename" to MuJoCo VFS (code $result).',
        );
      }
    });
  }

  @override
  void deleteFile(String filename) {
    _check();
    checkVfsFilename(filename);
    ffi.using((arena) {
      final result = g.mj_deleteFileVFS(
        ptr,
        filename.toNativeUtf8(allocator: arena).cast<Char>(),
      );
      if (result != 0 && result != -1) {
        throw StateError(
          'Failed to delete "$filename" from MuJoCo VFS (code $result).',
        );
      }
    });
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    // mj_deleteVFS frees the file contents, not the structure.
    g.mj_deleteVFS(ptr);
    ffi.calloc.free(ptr);
  }
}

class MjSpecNative(final Pointer<g.mjSpec> ptr)
    with DisposableOwner
    implements MjSpec {
  this {
    if (ptr == nullptr) throw StateError('Failed to allocate MuJoCo spec');
  }

  void _check() {
    if (isDisposed) throw StateError('Spec is disposed');
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    g.mj_deleteSpec(ptr);
  }
}

class MjModelNative(final Pointer<g.mjModel> ptr)
    with DisposableOwner
    implements MjModel {
  this {
    if (ptr == nullptr) throw StateError('Failed to allocate MuJoCo model');
  }

  void _check() {
    if (isDisposed) throw StateError('Model is disposed');
  }

  @override
  int get ngeom {
    _check();
    return ptr.ref.ngeom;
  }

  @override
  int get nmesh {
    _check();
    return ptr.ref.nmesh;
  }

  @override
  List<double> get center {
    _check();
    return List.generate(3, (i) => ptr.ref.stat.center[i]);
  }

  @override
  double get extent {
    _check();
    return ptr.ref.stat.extent;
  }

  @override
  MjGeomInfo geomById(int id) {
    _check();
    RangeError.checkValidIndex(id, this, 'id', ngeom);
    final m = ptr.ref;
    final mat = m.geom_matid[id];
    final color = (m.geom_rgba + id * 4).asTypedList(4).toList();
    final defaultColor =
        color[0] == 0.5 && color[1] == 0.5 && color[2] == 0.5 && color[3] == 1;
    return MjGeomInfo(
      id: id,
      name: _name(g.mjtObj.mjOBJ_GEOM, id),
      type: m.geom_type[id],
      group: m.geom_group[id],
      size: (m.geom_size + id * 3).asTypedList(3).toList(),
      rgba: mat >= 0 && defaultColor
          ? (m.mat_rgba + mat * 4).asTypedList(4).toList()
          : color,
      metallic: mat < 0 ? 0.05 : m.mat_metallic[mat],
      roughness: mat < 0 ? 0.6 : m.mat_roughness[mat],
      meshId: m.geom_dataid[id],
      materialId: mat,
    );
  }

  @override
  MjMeshInfo meshById(int id) {
    _check();
    RangeError.checkValidIndex(id, this, 'id', nmesh);
    final m = ptr.ref;
    final count = m.mesh_facenum[id];
    final positions = Float32List(count * 9);
    final normals = Float32List(count * 9);
    for (var f = 0; f < count; f++) {
      for (var c = 0; c < 3; c++) {
        final index = (m.mesh_faceadr[id] + f) * 3 + c;
        final vertex = m.mesh_vertadr[id] + m.mesh_face[index];
        final normal = m.mesh_normaladr[id] + m.mesh_facenormal[index];
        for (var a = 0; a < 3; a++) {
          positions[f * 9 + c * 3 + a] = m.mesh_vert[vertex * 3 + a];
          normals[f * 9 + c * 3 + a] = m.mesh_normal[normal * 3 + a];
        }
      }
    }
    return MjMeshInfo(positions, normals);
  }

  @override
  double get timestep {
    _check();
    return ptr.ref.opt.timestep;
  }

  @override
  int get njnt {
    _check();
    return ptr.ref.njnt;
  }

  @override
  int get nbody {
    _check();
    return ptr.ref.nbody;
  }

  String _name(g.mjtObj type, int id) {
    final name = g.mj_id2name(ptr, type.value, id);
    return name == nullptr ? '' : name.cast<ffi.Utf8>().toDartString();
  }

  @override
  MjJointInfo jointById(int id) {
    if (isDisposed) throw StateError('Model is disposed');
    RangeError.checkValidIndex(id, this, 'id', njnt);
    return .new(
      id: id,
      name: _name(.mjOBJ_JOINT, id),
      type: MjJointType.values[ptr.ref.jnt_type[id]],
      qposAddress: ptr.ref.jnt_qposadr[id],
      dofAddress: ptr.ref.jnt_dofadr[id],
    );
  }

  @override
  MjActuatorInfo actuatorById(int id) {
    if (isDisposed) throw StateError('Model is disposed');
    RangeError.checkValidIndex(id, this, 'id', nu);
    final jointTransmission =
        ptr.ref.actuator_trntype[id] == g.mjtTrn.mjTRN_JOINT.value;
    final joint = jointTransmission
        ? jointById(ptr.ref.actuator_trnid[2 * id])
        : null;
    final unitGear =
        ptr.ref.actuator_gear[6 * id] == 1 &&
        List.generate(
          5,
          (i) => ptr.ref.actuator_gear[6 * id + 1 + i],
        ).every((v) => v == 0);
    return .new(
      id: id,
      name: _name(.mjOBJ_ACTUATOR, id),
      joint: joint,
      isUnitTorqueMotor:
          jointTransmission &&
          unitGear &&
          ptr.ref.actuator_dyntype[id] == 0 &&
          ptr.ref.actuator_gaintype[id] == 0 &&
          ptr.ref.actuator_biastype[id] == 0 &&
          ptr.ref.actuator_gainprm[10 * id] == 1,
      controlRange: ptr.ref.actuator_ctrllimited[id]
          ? (
              lower: ptr.ref.actuator_ctrlrange[2 * id],
              upper: ptr.ref.actuator_ctrlrange[2 * id + 1],
            )
          : null,
    );
  }

  @override
  MjBodyInfo body(String name) {
    if (isDisposed) throw StateError('Model is disposed');
    final id = ffi.using(
      (arena) => g.mj_name2id(
        ptr,
        g.mjtObj.mjOBJ_BODY.value,
        name.toNativeUtf8(allocator: arena).cast(),
      ),
    );
    if (id < 0) throw ArgumentError.value(name, 'name', 'Unknown body');
    return bodyById(id);
  }

  @override
  MjBodyInfo bodyById(int id) {
    if (isDisposed) throw StateError('Model is disposed');
    RangeError.checkValidIndex(id, this, 'id', nbody);
    return .new(id, _name(.mjOBJ_BODY, id));
  }

  @override
  int get nq {
    _check();
    return ptr.ref.nq;
  }

  @override
  int get nv {
    _check();
    return ptr.ref.nv;
  }

  @override
  int get nu {
    _check();
    return ptr.ref.nu;
  }

  @override
  int get na {
    _check();
    return ptr.ref.na;
  }

  @override
  int get nsensor {
    _check();
    return ptr.ref.nsensor;
  }

  @override
  int get nsensordata {
    _check();
    return ptr.ref.nsensordata;
  }

  @override
  MjModelSensorViewsNative sensor(String name) {
    final id = ffi.using(
      (arena) => g.mj_name2id(
        ptr,
        g.mjtObj.mjOBJ_SENSOR.value,
        name.toNativeUtf8(allocator: arena).cast<Char>(),
      ),
    );
    return sensorById(id);
  }

  @override
  MjModelSensorViewsNative sensorById(int id) {
    RangeError.checkValidIndex(id, this, 'id', nsensor);
    return MjModelSensorViewsNative(this, id);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    g.mj_deleteModel(ptr);
  }
}

class MjDataNative._(
  final Pointer<g.mjData> ptr,
  @override final MjModelNative model,
) with DisposableOwner implements MjData {
  this {
    qpos = GuardedDoubleListView(
      MjDoubleListViewNative(ptr.ref.qpos, model.nq),
      _check,
    );
    qvel = GuardedDoubleListView(
      MjDoubleListViewNative(ptr.ref.qvel, model.nv),
      _check,
    );
    qacc = GuardedDoubleListView(
      MjDoubleListViewNative(ptr.ref.qacc, model.nv),
      _check,
    );
    act = GuardedDoubleListView(
      MjDoubleListViewNative(ptr.ref.act, model.na),
      _check,
    );
    ctrl = GuardedDoubleListView(
      MjDoubleListViewNative(ptr.ref.ctrl, model.nu),
      _check,
    );
    sensordata = GuardedDoubleListView(
      MjDoubleListViewNative(ptr.ref.sensordata, model.nsensordata),
      _check,
    );
  }

  factory MjDataNative(Pointer<g.mjData> ptr, MjModelNative model) {
    if (ptr == nullptr) throw StateError('Failed to allocate MuJoCo data');
    return MjDataNative._(ptr, model);
  }

  @override
  MjDataBodyViews body(String name) => bodyById(model.body(name).id);
  @override
  MjDataBodyViews bodyById(int id) {
    if (isDisposed || model.isDisposed) {
      throw StateError('Model or data is disposed');
    }
    return MjDataBodyViewsNative(this, model.bodyById(id));
  }

  void _check() {
    if (isDisposed || model.isDisposed) {
      throw StateError('Model or data is disposed');
    }
  }

  @override
  int get ncon {
    _check();
    return ptr.ref.ncon;
  }

  @override
  MjDoubleListView geomPosition(int id) {
    _check();
    RangeError.checkValidIndex(id, this, 'id', model.ngeom);
    return GuardedDoubleListView(
      MjDoubleListViewNative(ptr.ref.geom_xpos + id * 3, 3),
      _check,
    );
  }

  @override
  MjDoubleListView geomRotation(int id) {
    _check();
    RangeError.checkValidIndex(id, this, 'id', model.ngeom);
    return GuardedDoubleListView(
      MjDoubleListViewNative(ptr.ref.geom_xmat + id * 9, 9),
      _check,
    );
  }

  @override
  double get time {
    _check();
    return ptr.ref.time;
  }

  @override
  late final MjDoubleListView qpos;

  @override
  late final MjDoubleListView qvel;

  @override
  late final MjDoubleListView qacc;

  @override
  late final MjDoubleListView act;

  @override
  late final MjDoubleListView ctrl;

  @override
  late final MjDoubleListView sensordata;

  @override
  MjDataSensorViewsNative sensor(String name) =>
      sensorById(model.sensor(name).id);

  @override
  MjDataSensorViewsNative sensorById(int id) =>
      MjDataSensorViewsNative(this, model.sensorById(id));

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    g.mj_deleteData(ptr);
  }
}

class MjDoubleListViewNative(final Pointer<Double> ptr, final int _length)
    implements MjDoubleListView {
  @override
  int get length => _length;

  @override
  double operator [](int index) => ptr[index];

  @override
  void operator []=(int index, double value) => ptr[index] = value;

  @override
  List<double> toList() => ptr.asTypedList(length).toList();
}

class MjModelSensorViewsNative(
  final MjModelNative model,
  @override final int id,
) implements MjModelSensorViews {
  @override
  String get name {
    model._check();
    final name = g.mj_id2name(model.ptr, g.mjtObj.mjOBJ_SENSOR.value, id);
    return name == nullptr ? '' : name.cast<ffi.Utf8>().toDartString();
  }

  @override
  int get type {
    model._check();
    return model.ptr.ref.sensor_type[id];
  }

  @override
  MjSensorKind get kind {
    if (type == g.mjtSensor.mjSENS_ACCELEROMETER.value) {
      return .accelerometer;
    }
    if (type == g.mjtSensor.mjSENS_GYRO.value) {
      return .gyro;
    }
    if (type == g.mjtSensor.mjSENS_FRAMEQUAT.value) {
      return .frameQuaternion;
    }
    return .other;
  }

  @override
  int get dim {
    model._check();
    return model.ptr.ref.sensor_dim[id];
  }

  @override
  int get adr {
    model._check();
    return model.ptr.ref.sensor_adr[id];
  }
}

class MjDataSensorViewsNative(
  final MjDataNative owner,
  final MjModelSensorViewsNative sensor,
) implements MjDataSensorViews {
  this {
    owner._check();
    data = GuardedDoubleListView(
      MjDoubleListViewNative(owner.ptr.ref.sensordata + sensor.adr, sensor.dim),
      owner._check,
    );
  }
  @override
  int get id => sensor.id;
  @override
  String get name => sensor.name;
  @override
  late final MjDoubleListView data;
}

class MjDataBodyViewsNative(final MjDataNative owner, final MjBodyInfo info)
    implements MjDataBodyViews {
  void _check() {
    if (owner.isDisposed || owner.model.isDisposed) {
      throw StateError('Model or data is disposed');
    }
  }

  @override
  int get id => info.id;
  @override
  String get name => info.name;
  late final MjDoubleListView _position = GuardedDoubleListView(
    MjDoubleListViewNative(owner.ptr.ref.xpos + 3 * id, 3),
    _check,
  );
  late final MjDoubleListView _force = GuardedDoubleListView(
    MjDoubleListViewNative(owner.ptr.ref.xfrc_applied + 6 * id, 6),
    _check,
  );
  @override
  MjDoubleListView get position {
    _check();
    return _position;
  }

  @override
  MjDoubleListView get appliedForce {
    _check();
    return _force;
  }
}
