// ignore_for_file: non_constant_identifier_names
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../base.dart';
import '../model_info.dart';
import '../owner.dart';

final api = WebApi();
JSObject? _installed;

/// Registers the resolved official `loadMujoco()` module before creating models.
/// A process uses one WASM instance so existing model/data handles stay valid.
void initializeMujocoJs(JSObject module) {
  if (_installed != null && !_installed!.strictEquals(module).toDart) {
    throw StateError('A different MuJoCo WASM module is already registered');
  }
  _installed = module;
}

JSObject get _module =>
    _installed ??
    (throw StateError('Initialize MuJoCo WASM before using models'));
JSAny? _get(JSObject o, String key) => o.getProperty<JSAny?>(key.toJS);
JSObject _obj(JSObject o, String key) => _get(o, key) as JSObject;
double _number(JSObject o, String key) =>
    (_get(o, key) as JSNumber).toDartDouble;
int _integer(JSObject o, String key) => _number(o, key).toInt();
double _at(JSObject o, String key, int index) =>
    _number(_obj(o, key), '$index');
int _iat(JSObject o, String key, int index) => _at(o, key, index).toInt();
void _delete(JSObject o) => o.callMethod<JSAny?>('delete'.toJS);
String _name(JSObject model, int type, int id) {
  final result = _module.callMethod<JSAny?>(
    'mj_id2name'.toJS,
    model,
    type.toJS,
    id.toJS,
  );
  return result == null ? '' : (result as JSString).toDart;
}

int _id(JSObject model, int type, String name) => (_module.callMethod<JSNumber>(
  'mj_name2id'.toJS,
  model,
  type.toJS,
  name.toJS,
)).toDartInt;

final class WebApi implements BaseApi {
  @override
  String get version =>
      _module.callMethod<JSString>('mj_versionString'.toJS).toDart;
  @override
  MjVfsWeb MjVfs_new() => MjVfsWeb();

  @override
  MjSpecWeb mj_parseXMLString(String xml, {covariant MjVfsWeb? vfs}) {
    vfs?.check();
    try {
      return MjSpecWeb(
        vfs == null
            ? _module.callMethod<JSObject>('parseXMLString'.toJS, xml.toJS)
            : _module.callMethod<JSObject>(
                'parseXMLString'.toJS,
                xml.toJS,
                vfs.handle,
              ),
      );
    } catch (e) {
      throw FormatException('MuJoCo WASM XML parsing failed: $e');
    }
  }

  @override
  MjModelWeb mj_compile(covariant MjSpecWeb spec, {covariant MjVfsWeb? vfs}) {
    spec.check();
    vfs?.check();
    try {
      return MjModelWeb(
        vfs == null
            ? _module.callMethod<JSObject>('mj_compile'.toJS, spec.handle)
            : _module.callMethod<JSObject>(
                'mj_compile'.toJS,
                spec.handle,
                vfs.handle,
              ),
      );
    } catch (e) {
      throw FormatException('MuJoCo WASM compilation failed: $e');
    }
  }

  @override
  MjModelWeb mj_loadXML(String filename, {covariant MjVfsWeb? vfs}) {
    vfs?.check();
    try {
      final constructor = _obj(_module, 'MjModel');
      return MjModelWeb(
        vfs == null
            ? constructor.callMethod<JSObject>('mj_loadXML'.toJS, filename.toJS)
            : constructor.callMethod<JSObject>(
                'mj_loadXML'.toJS,
                filename.toJS,
                vfs.handle,
              ),
      );
    } catch (e) {
      throw FormatException('MuJoCo WASM virtual path load failed: $e');
    }
  }

  @override
  MjDataWeb MjData_new(covariant MjModelWeb model) {
    model.check();
    return MjDataWeb(
      _module
          .getProperty<JSFunction>('MjData'.toJS)
          .callAsConstructor<JSObject>(model.handle),
      model,
    );
  }

  @override
  void mj_forward(covariant MjModelWeb model, covariant MjDataWeb data) =>
      _module.callMethod<JSAny?>('mj_forward'.toJS, model.handle, data.handle);
  @override
  void mj_step(covariant MjModelWeb model, covariant MjDataWeb data) =>
      _module.callMethod<JSAny?>('mj_step'.toJS, model.handle, data.handle);
  @override
  void mj_resetData(covariant MjModelWeb model, covariant MjDataWeb data) =>
      _module.callMethod<JSAny?>(
        'mj_resetData'.toJS,
        model.handle,
        data.handle,
      );
}

class MjVfsWeb with DisposableOwner implements MjVfs {
  MjVfsWeb()
    : handle = _module
          .getProperty<JSFunction>('MjVFS'.toJS)
          .callAsConstructor<JSObject>();

  final JSObject handle;

  void check() {
    if (isDisposed) throw StateError('VFS is disposed');
  }

  @override
  void addBuffer(String filename, Uint8List bytes) {
    check();
    checkVfsFilename(filename);
    try {
      handle.callMethod<JSAny?>('addBuffer'.toJS, filename.toJS, bytes.toJS);
    } catch (e) {
      throw StateError('Failed to add "$filename" to MuJoCo VFS: $e');
    }
  }

  @override
  void deleteFile(String filename) {
    check();
    checkVfsFilename(filename);
    try {
      handle.callMethod<JSAny?>('deleteFile'.toJS, filename.toJS);
    } catch (e) {
      throw StateError('Failed to delete "$filename" from MuJoCo VFS: $e');
    }
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    _delete(handle);
  }
}

class MjSpecWeb(final JSObject handle) with DisposableOwner implements MjSpec {
  void check() {
    if (isDisposed) throw StateError('Spec is disposed');
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    _delete(handle);
  }
}

class MjModelWeb with DisposableOwner implements MjModel {
  MjModelWeb(this.handle);
  final JSObject handle;
  void check() {
    if (isDisposed) throw StateError('Model is disposed');
  }

  int _int(String key) {
    check();
    return _integer(handle, key);
  }

  @override
  int get nq => _int('nq');
  @override
  int get nv => _int('nv');
  @override
  int get nu => _int('nu');
  @override
  int get na => _int('na');
  @override
  int get njnt => _int('njnt');
  @override
  int get nbody => _int('nbody');
  @override
  int get nsensor => _int('nsensor');
  @override
  int get nsensordata => _int('nsensordata');
  @override
  int get ngeom => _int('ngeom');
  @override
  int get nmesh => _int('nmesh');
  @override
  double get timestep {
    check();
    final opt = _obj(handle, 'opt');
    try {
      return _number(opt, 'timestep');
    } finally {
      _delete(opt);
    }
  }

  @override
  List<double> get center {
    check();
    final stat = _obj(handle, 'stat');
    try {
      return List.generate(3, (i) => _at(stat, 'center', i));
    } finally {
      _delete(stat);
    }
  }

  @override
  double get extent {
    check();
    final stat = _obj(handle, 'stat');
    try {
      return _number(stat, 'extent');
    } finally {
      _delete(stat);
    }
  }

  @override
  MjJointInfo jointById(int id) {
    check();
    RangeError.checkValidIndex(id, this, 'id', njnt);
    return MjJointInfo(
      id: id,
      name: _name(handle, 3, id),
      type: MjJointType.values[_iat(handle, 'jnt_type', id)],
      qposAddress: _iat(handle, 'jnt_qposadr', id),
      dofAddress: _iat(handle, 'jnt_dofadr', id),
    );
  }

  @override
  MjActuatorInfo actuatorById(int id) {
    check();
    RangeError.checkValidIndex(id, this, 'id', nu);
    final jointTransmission = _iat(handle, 'actuator_trntype', id) == 0;
    return MjActuatorInfo(
      id: id,
      name: _name(handle, 19, id),
      joint: jointTransmission
          ? jointById(_iat(handle, 'actuator_trnid', 2 * id))
          : null,
      isUnitTorqueMotor:
          jointTransmission &&
          _at(handle, 'actuator_gear', 6 * id) == 1 &&
          List.generate(
            5,
            (i) => _at(handle, 'actuator_gear', 6 * id + 1 + i),
          ).every((v) => v == 0) &&
          _iat(handle, 'actuator_dyntype', id) == 0 &&
          _iat(handle, 'actuator_gaintype', id) == 0 &&
          _iat(handle, 'actuator_biastype', id) == 0 &&
          _at(handle, 'actuator_gainprm', 10 * id) == 1,
      controlRange: _iat(handle, 'actuator_ctrllimited', id) != 0
          ? (
              lower: _at(handle, 'actuator_ctrlrange', 2 * id),
              upper: _at(handle, 'actuator_ctrlrange', 2 * id + 1),
            )
          : null,
    );
  }

  @override
  MjBodyInfo body(String name) {
    check();
    final id = _id(handle, 1, name);
    if (id < 0) throw ArgumentError.value(name, 'name', 'Unknown body');
    return bodyById(id);
  }

  @override
  MjBodyInfo bodyById(int id) {
    check();
    RangeError.checkValidIndex(id, this, 'id', nbody);
    return MjBodyInfo(id, _name(handle, 1, id));
  }

  @override
  MjModelSensorViews sensor(String name) {
    check();
    return sensorById(_id(handle, 20, name));
  }

  @override
  MjModelSensorViews sensorById(int id) {
    check();
    RangeError.checkValidIndex(id, this, 'id', nsensor);
    return _Sensor(this, id);
  }

  @override
  MjGeomInfo geomById(int id) {
    check();
    RangeError.checkValidIndex(id, this, 'id', ngeom);
    final mat = _iat(handle, 'geom_matid', id);
    final rgba = List.generate(4, (i) => _at(handle, 'geom_rgba', 4 * id + i));
    final defaultColor =
        rgba[0] == 0.5 && rgba[1] == 0.5 && rgba[2] == 0.5 && rgba[3] == 1;
    return MjGeomInfo(
      id: id,
      name: _name(handle, 5, id),
      type: _iat(handle, 'geom_type', id),
      group: _iat(handle, 'geom_group', id),
      size: List.generate(3, (i) => _at(handle, 'geom_size', 3 * id + i)),
      rgba: mat >= 0 && defaultColor
          ? List.generate(4, (i) => _at(handle, 'mat_rgba', 4 * mat + i))
          : rgba,
      metallic: mat < 0 ? 0.05 : _at(handle, 'mat_metallic', mat),
      roughness: mat < 0 ? 0.6 : _at(handle, 'mat_roughness', mat),
      meshId: _iat(handle, 'geom_dataid', id),
      materialId: mat,
    );
  }

  @override
  MjMeshInfo meshById(int id) {
    check();
    RangeError.checkValidIndex(id, this, 'id', nmesh);
    final count = _iat(handle, 'mesh_facenum', id),
        faceBase = _iat(handle, 'mesh_faceadr', id),
        vertBase = _iat(handle, 'mesh_vertadr', id),
        normalBase = _iat(handle, 'mesh_normaladr', id);
    // Acquire the compiled arrays once. No physics calls or WASM allocations
    // occur while copying, so views cannot be invalidated by memory growth.
    final vertices = (_get(handle, 'mesh_vert') as JSFloat32Array).toDart;
    final normalValues = (_get(handle, 'mesh_normal') as JSFloat32Array).toDart;
    final faces = (_get(handle, 'mesh_face') as JSInt32Array).toDart;
    final faceNormals =
        (_get(handle, 'mesh_facenormal') as JSInt32Array).toDart;
    final positions = Float32List(count * 9), normals = Float32List(count * 9);
    for (var f = 0; f < count; f++) {
      for (var c = 0; c < 3; c++) {
        final index = (faceBase + f) * 3 + c;
        final vertex = vertBase + faces[index],
            normal = normalBase + faceNormals[index];
        for (var a = 0; a < 3; a++) {
          positions[f * 9 + c * 3 + a] = vertices[vertex * 3 + a];
          normals[f * 9 + c * 3 + a] = normalValues[normal * 3 + a];
        }
      }
    }
    return MjMeshInfo(positions, normals);
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    _delete(handle);
  }
}

class _View implements MjDoubleListView {
  _View(this.object, this.field, this.check, {this.start = 0, this.count});
  final JSObject object;
  final String field;
  final void Function() check;
  final int start;
  final int? count;
  @override
  int get length {
    check();
    return count ?? _integer(_obj(object, field), 'length');
  }

  void _check(int i) {
    check();
    RangeError.checkValidIndex(i, this, 'index', length);
  }

  @override
  double operator [](int i) {
    _check(i);
    return _at(object, field, start + i);
  }

  @override
  void operator []=(int i, double v) {
    _check(i);
    _obj(object, field).setProperty('${start + i}'.toJS, v.toJS);
  }

  @override
  List<double> toList() => List.generate(length, (i) => this[i]);
}

class MjDataWeb with DisposableOwner implements MjData {
  MjDataWeb(this.handle, this.model);
  final JSObject handle;
  @override
  final MjModelWeb model;
  void check() {
    model.check();
    if (isDisposed) throw StateError('Data is disposed');
  }

  @override
  double get time {
    check();
    return _number(handle, 'time');
  }

  @override
  int get ncon {
    check();
    return _integer(handle, 'ncon');
  }

  @override
  late final MjDoubleListView qpos = _View(handle, 'qpos', check);
  @override
  late final MjDoubleListView qvel = _View(handle, 'qvel', check);
  @override
  late final MjDoubleListView qacc = _View(handle, 'qacc', check);
  @override
  late final MjDoubleListView act = _View(handle, 'act', check);
  @override
  late final MjDoubleListView ctrl = _View(handle, 'ctrl', check);
  @override
  late final MjDoubleListView sensordata = _View(handle, 'sensordata', check);
  @override
  MjDoubleListView geomPosition(int id) {
    check();
    RangeError.checkValidIndex(id, this, 'id', model.ngeom);
    return _View(handle, 'geom_xpos', check, start: id * 3, count: 3);
  }

  @override
  MjDoubleListView geomRotation(int id) {
    check();
    RangeError.checkValidIndex(id, this, 'id', model.ngeom);
    return _View(handle, 'geom_xmat', check, start: id * 9, count: 9);
  }

  @override
  MjDataBodyViews body(String name) => bodyById(model.body(name).id);
  @override
  MjDataBodyViews bodyById(int id) {
    check();
    return _Body(this, model.bodyById(id));
  }

  @override
  MjDataSensorViews sensor(String name) => sensorById(model.sensor(name).id);
  @override
  MjDataSensorViews sensorById(int id) {
    check();
    return _DataSensor(this, model.sensorById(id));
  }

  @override
  void dispose() {
    if (isDisposed) return;
    super.dispose();
    _delete(handle);
  }
}

class _Body implements MjDataBodyViews {
  _Body(this.owner, this.info);
  final MjDataWeb owner;
  final MjBodyInfo info;
  @override
  int get id => info.id;
  @override
  String get name => info.name;
  @override
  MjDoubleListView get position =>
      _View(owner.handle, 'xpos', owner.check, start: id * 3, count: 3);
  @override
  MjDoubleListView get appliedForce =>
      _View(owner.handle, 'xfrc_applied', owner.check, start: id * 6, count: 6);
}

class _Sensor implements MjModelSensorViews {
  _Sensor(this.model, this.id);
  final MjModelWeb model;
  @override
  final int id;
  int _read(String field) {
    model.check();
    return _iat(model.handle, field, id);
  }

  @override
  String get name {
    model.check();
    return _name(model.handle, 20, id);
  }

  @override
  int get type => _read('sensor_type');
  @override
  int get dim => _read('sensor_dim');
  @override
  int get adr => _read('sensor_adr');
  @override
  MjSensorKind get kind {
    final types = _obj(_module, 'mjtSensor');
    if (type == _integer(_obj(types, 'mjSENS_ACCELEROMETER'), 'value')) {
      return MjSensorKind.accelerometer;
    }
    if (type == _integer(_obj(types, 'mjSENS_GYRO'), 'value')) {
      return MjSensorKind.gyro;
    }
    if (type == _integer(_obj(types, 'mjSENS_FRAMEQUAT'), 'value')) {
      return MjSensorKind.frameQuaternion;
    }
    return MjSensorKind.other;
  }
}

class _DataSensor implements MjDataSensorViews {
  _DataSensor(this.owner, this.info);
  final MjDataWeb owner;
  final MjModelSensorViews info;
  @override
  int get id => info.id;
  @override
  String get name => info.name;
  @override
  MjDoubleListView get data => _View(
    owner.handle,
    'sensordata',
    owner.check,
    start: info.adr,
    count: info.dim,
  );
}
