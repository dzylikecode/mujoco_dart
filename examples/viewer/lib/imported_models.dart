import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:mujoco/mujoco.dart';
import 'package:path/path.dart' as p;

// All imported bytes live in one VFS, shared across XML selections.
class ImportedModels {
  ImportedModels._(this._vfs, this.xmlPaths, this.fileCount);

  factory ImportedModels.fromFiles(Map<String, Uint8List> files) {
    final xmlPaths =
        files.keys
            .where((name) => p.posix.extension(name).toLowerCase() == '.xml')
            .toList()
          ..sort();
    if (xmlPaths.isEmpty) {
      throw const FormatException('No XML files found in this drop.');
    }
    final vfs = MjVfs();
    try {
      for (final entry in files.entries) {
        vfs.addBuffer(entry.key, entry.value);
      }
      return ImportedModels._(vfs, List.unmodifiable(xmlPaths), files.length);
    } on Object {
      vfs.dispose();
      rethrow;
    }
  }

  final MjVfs _vfs;
  final List<String> xmlPaths;
  final int fileCount;

  MjModel load(String path) {
    if (!xmlPaths.contains(path)) throw ArgumentError.value(path, 'path');
    return MjModel.from_xml_path(path, vfs: _vfs);
  }

  void dispose() => _vfs.dispose();
}

// Consume providers while onDrop is active; no platform handles escape it.
Future<ImportedModels> readDroppedModels(List<DropItem> items) async {
  final files = <String, Uint8List>{};

  Future<void> readFile(XFile file, String path) async {
    if (files.containsKey(path)) {
      throw FormatException('Two dropped files have the same path: $path');
    }
    files[path] = await file.readAsBytes();
  }

  Future<void> readDirectory(XDirectory directory, String prefix) async {
    await for (final entity in directory.list()) {
      final segments = Uri.parse(entity.uri).pathSegments
          .where((s) => s.isNotEmpty);
      final name = entity is XFile ? await entity.name() : null;
      final label = name ?? (segments.isEmpty ? null : segments.last);
      if (label == null) {
        throw const FormatException('Directory entry has no name.');
      }
      final path = p.posix.join(prefix, label);
      if (entity is XFile) {
        await readFile(entity, path);
      } else if (entity is XDirectory) {
        await readDirectory(entity, path);
      } else {
        throw FormatException('Cannot read dropped entry: $path');
      }
    }
  }

  for (final item in items) {
    final bookmark = switch (item) {
      DropFileItem(:final appleBookmark) => appleBookmark,
      DropDirectoryItem(:final appleBookmark) => appleBookmark,
      _ => null,
    };
    var accessed = false;
    try {
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.macOS &&
          bookmark != null) {
        accessed = await DesktopDrop.instance
            .startAccessingSecurityScopedResource(bookmark: bookmark);
        if (!accessed) {
          throw StateError('Cannot read the dropped folder or file.');
        }
      }
      if (item is DropFileItem) {
        await readFile(item.file, item.name);
      } else if (item is DropDirectoryItem) {
        await readDirectory(item.directory, item.name);
      }
    } finally {
      if (accessed) {
        await DesktopDrop.instance.stopAccessingSecurityScopedResource(
          bookmark: bookmark!,
        );
      }
    }
  }
  return ImportedModels.fromFiles(files);
}
