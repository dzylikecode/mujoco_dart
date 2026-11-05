import 'dart:math' as math;

import 'package:flutter_scene/scene.dart' as scene;
import 'package:vector_math/vector_math.dart' as vm;

import 'package:flutter/foundation.dart';
import 'package:mujoco/mujoco.dart';

import 'plane_surface.dart';

// MuJoCo is Z-up. Convert the complete world once, preserving the compiled
// geom/mesh coordinate frames: (x, y, z) -> (x, z, -y).
vm.Matrix4 geomTransform(List<double> p, List<double> r) => vm.Matrix4(
  r[0],
  r[3],
  r[6],
  0,
  r[1],
  r[4],
  r[7],
  0,
  r[2],
  r[5],
  r[8],
  0,
  p[0],
  p[1],
  p[2],
  1,
);

vm.Vector3 viewerPosition(List<double> p) => vm.Vector3(p[0], p[2], -p[1]);

class MujocoViewerController extends ChangeNotifier {
  static Future<MujocoViewerController> create({
    required MjModel model,
    required MjData data,
  }) async {
    if (!identical(model, data.model)) {
      throw ArgumentError('Data belongs to a different model');
    }
    if (model.isDisposed || data.isDisposed) {
      throw StateError('Model or data is disposed');
    }
    await scene.Scene.initializeStaticResources();
    return MujocoViewerController._(model, data);
  }

  MujocoViewerController._(this.model, this.data) {
    root.rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -math.pi / 2);
    world.add(root);
    cameraNode.addComponent(camera);
    cameraNode.addComponent(orbit);
    // Components run in attachment order, after this frame's camera movement.
    cameraNode.addComponent(_InfinitePlanesUpdater(this));
    world.add(cameraNode);
    for (var i = 0; i < model.ngeom; i++) {
      _addGeom(i);
    }
    for (final group in groups.where((g) => g >= 3)) {
      setGroup(group, false);
    }
    sync();
    frameModel();
  }

  final MjModel model;
  final MjData data;
  final world = scene.Scene();
  final root = scene.Node(name: 'MuJoCo Z-up world');
  final cameraNode = scene.Node(name: 'Viewer camera');
  final camera = scene.CameraComponent();
  final orbit = scene.OrbitCameraController(
    distance: 7,
    azimuth: -1.0,
    polar: 0.35,
  );
  final Map<int, scene.Node> nodes = {};
  final Map<int, scene.Geometry> _meshCache = {};
  final Map<int, scene.Texture2D> _textureCache = {};
  final Map<int, _InfinitePlanePatch> _infinitePlanes = {};
  double _aspectRatio = 1;
  final List<String> warnings = [];
  final Set<int> groups = {};
  final Set<int> hiddenGroups = {};
  int triangles = 0;

  void _addGeom(int id) {
    final geom = model.geomById(id);
    final size = geom.size;
    final type = geom.type;
    scene.Geometry geometry;
    final scale = vm.Vector3.all(1);
    // Native MuJoCo type numbers are stable in its C ABI.
    switch (type) {
      case 0:
        final surface = planeSurface(
          geom,
          infiniteHalfExtent: math.max(20, model.extent * 4),
        );
        geometry = scene.MeshGeometry.fromArrays(
          positions: surface.positions,
          normals: surface.normals,
          texCoords: surface.texCoords,
          storage: size[0] <= 0 || size[1] <= 0
              ? scene.GeometryStorage.updatable
              : scene.GeometryStorage.fixed,
        );
      case 2:
        geometry = scene.SphereGeometry(radius: size[0]);
      case 3:
        geometry = scene.CapsuleGeometry(radius: size[0], height: size[1] * 2);
      case 4:
        geometry = scene.SphereGeometry(radius: 1);
        scale.setValues(size[0], size[1], size[2]);
      case 5:
        geometry = scene.CylinderGeometry(
          bottomRadius: size[0],
          topRadius: size[0],
          height: size[1] * 2,
        );
      case 6:
        geometry = scene.CuboidGeometry(
          vm.Vector3(size[0] * 2, size[1] * 2, size[2] * 2),
        );
      case 7:
        final meshId = geom.meshId;
        geometry = _meshCache.putIfAbsent(meshId, () => _mesh(meshId));
      default:
        warnings.add('${model.geomById(id).name}: unsupported geom type $type');
        return;
    }
    final rgba = geom.rgba;
    final material = scene.PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(rgba[0], rgba[1], rgba[2], rgba[3])
      ..metallicFactor = geom.metallic
      ..roughnessFactor = geom.roughness;
    if (type == 0 && geom.colorTextureId >= 0) {
      final textureId = geom.colorTextureId;
      final texture = model.textureById(textureId);
      if (texture.type == MjTextureType.twoD) {
        material.baseColorTexture = _textureCache.putIfAbsent(
          textureId,
          () => scene.Texture2D.fromPixels(
            textureRgba(texture),
            texture.width,
            texture.height,
          ),
        );
      } else {
        warnings.add(
          '${geom.name}: plane texture ${texture.type.name} is not supported',
        );
      }
    }
    final shape = scene.Node(mesh: scene.Mesh(geometry, material))
      ..scale = scale;
    if (type == 3 || type == 5) {
      // Scene primitives use local Y; MuJoCo capsules/cylinders use local Z.
      shape.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(1, 0, 0),
        math.pi / 2,
      );
    }
    if (type == 0 && (size[0] <= 0 || size[1] <= 0)) {
      _infinitePlanes[id] = _InfinitePlanePatch(
        geom,
        shape,
        geometry as scene.MeshGeometry,
        math.max(20, model.extent * 4),
      );
    }
    final node = scene.Node(name: model.geomById(id).name)..add(shape);
    nodes[id] = node;
    groups.add(geom.group);
    root.add(node);
  }

  scene.Geometry _mesh(int meshId) {
    final mesh = model.meshById(meshId);
    triangles += mesh.triangleCount;
    return scene.MeshGeometry.fromArrays(
      positions: mesh.positions,
      normals: mesh.normals,
    );
  }

  void setGroup(int group, bool visible) {
    if (visible) {
      hiddenGroups.remove(group);
    } else {
      hiddenGroups.add(group);
    }
    for (final entry in nodes.entries) {
      final attached = entry.value.parent != null;
      final show = !hiddenGroups.contains(model.geomById(entry.key).group);
      if (show && !attached) root.add(entry.value);
      if (!show && attached) root.remove(entry.value);
    }
    notifyListeners();
  }

  /// Synchronizes compiled geom poses and the viewport used by infinite planes.
  ///
  /// The viewer widget supplies [aspectRatio] automatically. Custom rendering loops
  /// should pass their render target's width divided by height.
  void sync({double? aspectRatio}) {
    if (aspectRatio != null && aspectRatio.isFinite && aspectRatio > 0) {
      _aspectRatio = aspectRatio;
    }
    for (final entry in nodes.entries) {
      entry.value.localTransform = geomTransform(
        data.geomPosition(entry.key).toList(),
        data.geomRotation(entry.key).toList(),
      );
    }
  }

  void _syncInfinitePlanes() {
    if (_infinitePlanes.isEmpty) return;
    final reach = projectionReach(
      camera.projection.getProjectionMatrix(_aspectRatio),
    );
    final eye = camera.toCamera().position;
    final mujocoEye = vm.Vector3(eye.x, -eye.z, eye.y);
    for (final entry in _infinitePlanes.entries) {
      final patch = entry.value;
      final inverse = vm.Matrix4.inverted(nodes[entry.key]!.localTransform);
      final localEye = inverse.transform3(mujocoEye);
      final placement = infinitePlanePlacement(
        patch.geom,
        localEye,
        viewReach: reach,
      );
      if ((placement.halfExtent - patch.halfExtent).abs() > 1e-6) {
        final surface = planeSurface(
          patch.geom,
          infiniteHalfExtent: placement.halfExtent,
        );
        patch.geometry.updatePositions(surface.positions);
        patch.geometry.updateTexCoords(surface.texCoords);
        patch.halfExtent = placement.halfExtent;
      }
      patch.shape.position = placement.center;
    }
  }

  void frameModel() {
    final center = viewerPosition(model.center);
    orbit.target = center;
    orbit.frame(
      vm.Aabb3.minMax(
        center - vm.Vector3.all(model.extent * 0.5),
        center + vm.Vector3.all(model.extent * 0.5),
      ),
    );
    orbit.update(1);
    _syncInfinitePlanes();
  }

  @override
  void dispose() {
    world.dispose();
    root.removeAll();
    nodes.clear();
    _meshCache.clear();
    _textureCache.clear();
    _infinitePlanes.clear();
    super.dispose();
  }
}

class _InfinitePlanePatch {
  _InfinitePlanePatch(this.geom, this.shape, this.geometry, this.halfExtent);
  final MjGeomInfo geom;
  final scene.Node shape;
  final scene.MeshGeometry geometry;
  double halfExtent;
}

class _InfinitePlanesUpdater(final MujocoViewerController controller)
    extends scene.Component {
  @override
  void update(double deltaSeconds) => controller._syncInfinitePlanes();
}
