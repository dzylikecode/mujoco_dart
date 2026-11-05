import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'patch_bool_views.dart' as bool_views;

Future<void> main(List<String> arguments) async {
  if (arguments.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/update.dart [--archive path/to/package.tgz]\n'
      'Downloads the version locked in UPSTREAM.json, verifies it, and patches assets.',
    );
    return;
  }
  if (arguments.isNotEmpty &&
      (arguments.length != 2 || arguments.first != '--archive')) {
    stderr.writeln(
      'Usage: dart run tool/update.dart [--archive path/to/package.tgz]',
    );
    exitCode = 64;
    return;
  }
  try {
    await update(arguments.isEmpty ? null : File(arguments[1]));
  } on Object catch (error) {
    stderr.writeln('MuJoCo asset update failed: $error');
    exitCode = 1;
  }
}

Future<void> update(File? localArchive) async {
  final root = Platform.script.resolve('../');
  final manifestFile = File.fromUri(root.resolve('UPSTREAM.json'));
  final manifest =
      jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
  final source = Uri.parse(manifest['source'] as String);
  if (source.scheme != 'https' || source.host != 'registry.npmjs.org') {
    throw StateError('Expected an HTTPS npm registry archive');
  }
  stdout.writeln(
    'MuJoCo ${manifest['version']}: ${localArchive?.path ?? source}',
  );
  final bytes = localArchive == null
      ? await download(source)
      : await localArchive.readAsBytes();
  final integrity = 'sha512-${base64.encode(sha512.convert(bytes).bytes)}';
  if (integrity != manifest['integrity']) {
    throw StateError('Archive integrity mismatch');
  }

  // Read only exact single-threaded members; never extract archive paths to disk.
  final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
  List<int> member(String name) {
    final matches = archive.files.where((file) => file.name == 'package/$name');
    if (matches.length != 1 || !matches.single.isFile) {
      throw StateError('Expected exactly one package/$name');
    }
    return matches.single.content;
  }

  final package =
      jsonDecode(utf8.decode(member('package.json'))) as Map<String, dynamic>;
  if (package['name'] != manifest['package'] ||
      package['version'] != manifest['version']) {
    throw StateError('Archive package name/version mismatch');
  }
  final js = member('mujoco.js');
  final wasm = member('mujoco.wasm');
  for (final entry in {'mujoco.js': js, 'mujoco.wasm': wasm}.entries) {
    if (sha256.convert(entry.value).toString() !=
        manifest['files'][entry.key]) {
      throw StateError('Upstream ${entry.key} hash mismatch');
    }
  }
  final patchedJs = bool_views.patchBoolViews(js, manifest);
  bool_views.recordBoolViewPatch(manifest, patchedJs);
  final outputs = <File, List<int>>{
    File.fromUri(root.resolve('assets/mujoco.js')): patchedJs,
    File.fromUri(root.resolve('assets/mujoco.wasm')): wasm,
    manifestFile: utf8.encode(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    ),
  };

  // Validate everything before writing; restore existing files on write failure.
  final backups = <File, List<int>?>{};
  for (final file in outputs.keys) {
    backups[file] = await file.exists() ? await file.readAsBytes() : null;
  }
  try {
    for (final entry in outputs.entries) {
      await entry.key.writeAsBytes(entry.value, flush: true);
    }
  } on Object {
    for (final entry in backups.entries) {
      if (entry.value case final bytes?) {
        await entry.key.writeAsBytes(bytes, flush: true);
      } else if (await entry.key.exists()) {
        await entry.key.delete();
      }
    }
    rethrow;
  }
  stdout.writeln(
    'Updated assets/mujoco.js, assets/mujoco.wasm and UPSTREAM.json.',
  );
}

Future<List<int>> download(Uri source) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client
        .getUrl(source)
        .timeout(const Duration(seconds: 30));
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Download returned HTTP ${response.statusCode}',
        uri: source,
      );
    }
    return await response
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk))
        .timeout(const Duration(minutes: 2));
  } finally {
    client.close(force: true);
  }
}
