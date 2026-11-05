import 'dart:io';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');
  final checks = Directory.fromUri(
    packageRoot.resolve('.dart_tool/native_assets_check/'),
  )..createSync(recursive: true);
  final runDirectory = checks.createTempSync('run_');

  Future<void> run(String executable, List<String> arguments) async {
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: packageRoot.toFilePath(),
      environment: {'DASH__SUPPRESS_ANALYTICS': 'true'},
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        arguments,
        'Native asset verification failed',
        result.exitCode,
      );
    }
  }

  Future<Uri> build(String entryPoint, String name) async {
    final output = runDirectory.uri.resolve('$name/');
    await run(Platform.resolvedExecutable, [
      'build',
      'cli',
      '--target=$entryPoint',
      '--output=${output.toFilePath()}',
    ]);
    return output.resolve('bundle/');
  }

  List<File> mujocoLibraries(Uri bundle) {
    final libraries = Directory.fromUri(bundle.resolve('lib/'));
    if (!libraries.existsSync()) return [];
    return libraries.listSync().whereType<File>().where((file) {
      return file.uri.pathSegments.last.contains('mujoco');
    }).toList();
  }

  Future<void> runBundle(Uri bundle) async {
    final executable = Directory.fromUri(bundle.resolve('bin/'))
        .listSync()
        .whereType<File>()
        .single;
    await run(executable.path, []);
  }

  final used = await build('example/native_smoke.dart', 'used');
  if (mujocoLibraries(used).length != 1) {
    throw StateError('Expected one bundled MuJoCo library: $used');
  }
  await runBundle(used);

  final unusedSource = File.fromUri(runDirectory.uri.resolve('unused.dart'));
  unusedSource.writeAsStringSync('''
// ignore: unused_import
import 'package:mujoco/mujoco.dart';
void main() { print('MuJoCo imported without native calls'); }
''');
  final unused = await build(unusedSource.path, 'unused');
  if (mujocoLibraries(unused).isNotEmpty) {
    throw StateError('Unused MuJoCo library was bundled: $unused');
  }
  await runBundle(unused);
  print('Native asset checks passed. Artifacts: ${runDirectory.path}');
}
