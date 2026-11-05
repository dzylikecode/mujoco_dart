import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file_io/cross_file_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene_lab/imported_models.dart';
import 'package:mujoco/mujoco.dart';
import 'package:path/path.dart' as p;

Uint8List bytes(String xml) => Uint8List.fromList(utf8.encode(xml));

Map<String, Uint8List> fixture() => {
  'robot/models/02.xml': bytes(
    '<mujoco><worldbody><geom type="box" size=".1 .2 .3"/></worldbody></mujoco>',
  ),
  'robot/models/01.xml': bytes('''<mujoco><include file="../parts/body.xml"/>
    <asset><mesh name="mesh" file="../meshes/tetra.obj"/></asset>
    <worldbody><geom type="mesh" mesh="mesh"/></worldbody></mujoco>'''),
  'robot/parts/body.xml': bytes(
    '<mujoco><worldbody><body><freejoint/><geom type="sphere" size=".1"/></body></worldbody></mujoco>',
  ),
  'robot/meshes/tetra.obj': bytes(
    'v 0 0 0\nv 1 0 0\nv 0 1 0\nv 0 0 1\nf 1 3 2\nf 1 2 4\nf 1 4 3\nf 2 3 4\n',
  ),
};

void main() {
  setUpAll(CrossFileIO.registerWith);
  test('Imported XMLs sort deterministically and share relative includes and meshes', () {
    final library = ImportedModels.fromFiles(fixture());
    try {
      expect(library.xmlPaths.first, 'robot/models/01.xml');
      expect(library.fileCount, 4);
      final first = library.load(library.xmlPaths.first);
      try {
        expect(first.nq, 7);
        expect(first.nmesh, 1);
        final second = library.load('robot/models/02.xml');
        try {
          expect(second.nq, 0);
          expect(second.geomById(0).size, [.1, .2, .3]);
        } finally {
          second.dispose();
        }
      } finally {
        first.dispose();
      }
    } finally {
      library.dispose();
    }
  });

  test('A broken XML does not prevent selecting another model', () {
    final library = ImportedModels.fromFiles({
      'a.xml': bytes('<invalid>'),
      'b.xml': bytes('<mujoco/>'),
    });
    try {
      expect(() => library.load(library.xmlPaths.first), throwsFormatException);
      final model = library.load('b.xml');
      library.dispose();
      library.dispose();
      try {
        final data = MjData(model);
        try {
          mj_step(model, data);
          expect(data.time, greaterThan(0));
        } finally {
          data.dispose();
        }
      } finally {
        model.dispose();
      }
      expect(() => library.load('b.xml'), throwsStateError);
    } finally {
      library.dispose();
    }
  });

  test('A drop without any XML is rejected', () {
    expect(
      () => ImportedModels.fromFiles({'mesh.obj': bytes('mesh')}),
      throwsFormatException,
    );
  });

  test(
    'A directory drop reads nested files before the drop callback ends',
    () async {
      final temporary = await Directory.systemTemp.createTemp('mujoco-drop-');
      try {
        for (final entry in fixture().entries) {
          final file = File(
            p.joinAll([temporary.path, ...p.posix.split(entry.key)]),
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(entry.value);
        }
        final library = await readDroppedModels([
          DropDirectoryItem(
            name: 'robot',
            directory: XDirectory.fileSystem(
              path: p.join(temporary.path, 'robot'),
            ),
          ),
        ]);
        // The library owns copied data, not the dropped file handles.
        await temporary.delete(recursive: true);
        try {
          expect(library.xmlPaths.first, 'robot/models/01.xml');
          final model = library.load(library.xmlPaths.first);
          try {
            expect(model.nq, 7);
            expect(model.nmesh, 1);
          } finally {
            model.dispose();
          }
        } finally {
          library.dispose();
        }
      } finally {
        if (await temporary.exists()) await temporary.delete(recursive: true);
      }
    },
  );
}
