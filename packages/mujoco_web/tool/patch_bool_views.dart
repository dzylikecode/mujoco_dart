// Reproduce the documented bool-memory-view fix against official 3.12.0 JS.
// Usage: dart run tool/patch_bool_views.dart /path/to/upstream/mujoco.js
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/patch_bool_views.dart /path/to/upstream/mujoco.js',
    );
    exitCode = 64;
    return;
  }

  final root = Platform.script.resolve('../');
  final manifestFile = File.fromUri(root.resolve('UPSTREAM.json'));
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final source = await File(arguments.single).readAsBytes();
  final output = patchBoolViews(source, manifest);
  await File.fromUri(root.resolve('assets/mujoco.js')).writeAsBytes(output);
  recordBoolViewPatch(manifest, output);
  await manifestFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
}

void recordBoolViewPatch(Map<String, dynamic> manifest, List<int> output) {
  manifest['patches'] = [
    {
      'file': 'mujoco.js',
      'description': 'Register missing Emscripten memory_view<bool> as one-byte Uint8Array on first use',
      'sha256': sha256.convert(output).toString(),
      'script': 'tool/patch_bool_views.dart',
    },
  ];
}

List<int> patchBoolViews(List<int> source, Map<String, dynamic> manifest) {
  if (manifest['version'] != '3.12.0') {
    throw StateError(
      'Review the bool-view patch for this MuJoCo version first',
    );
  }
  if (sha256.convert(source).toString() != manifest['files']['mujoco.js']) {
    throw StateError('Unexpected upstream JS hash');
  }

  const needle = '  var __emval_take_value = (type, arg) => {\n';
  const patch = '''      // mujoco_web compatibility fix: official 3.12.0 does not register
      // memory_view<bool>. Emscripten represents this as {length, pointer};
      // MuJoCo bool arrays contain one byte per element, exposed as Uint8Array.
      if (!registeredTypes[type] && getTypeName(type) === 'N10emscripten11memory_viewIbEE') {
        const decodeBoolView = (handle) => new Uint8Array(
          HEAPU8.buffer, HEAPU32[(handle + 4) >> 2], HEAPU32[handle >> 2]);
        registerType(type, {
          name: 'emscripten::memory_view<bool>',
          fromWireType: decodeBoolView,
          readValueFromPointer: decodeBoolView,
          argPackAdvance: GenericWireTypeSize,
        });
      }
''';
  final sourceText = utf8.decode(source);
  if (needle.allMatches(sourceText).length != 1) {
    throw StateError('Patch anchor changed');
  }
  final output = utf8.encode(sourceText.replaceFirst(needle, needle + patch));
  return output;
}
