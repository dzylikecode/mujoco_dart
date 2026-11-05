import 'dart:io';

import 'package:ffigen/ffigen.dart';

Future<void> main() async {
  final packageRoot = Platform.script.resolve('../');

  final generator = FfiGenerator(
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/backend/native.g.dart'),
      ),
      recordUseMapping: packageRoot.resolve(
        'lib/src/backend/mujoco.record_use_mapping.g.dart',
      ),
    ),

    input: Input(
      entryPoints: [packageRoot.resolve('dist/include/mujoco.h')],
      include: (header) => header.path.contains('mujoco'),
      compilerOptions: [
        '-I',
        packageRoot.resolve('dist/include').toFilePath(),
        if (Platform.isMacOS) ...['-isysroot', macSdkPath],
      ],
    ),

    visitors: [
      Visitor(
        func: (node) {
          node.isIncluded = true;
          node.recordUse = true;
        },
        struct: (node) {
          node.isIncluded = true;
        },
        typealias: (node) {
          node.isIncluded = .always;
        },
      ),
    ],
  );

  await generator.generate();
}
