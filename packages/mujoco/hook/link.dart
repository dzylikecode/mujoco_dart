import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:mujoco/src/backend/mujoco.record_use_mapping.g.dart';
import 'package:mujoco/src/xmake.dart';

void main(List<String> args) async {
  await link(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    await xmakeLibrary.link(
      input: input,
      output: output,
      linkerOptions: .treeshake(
        // The merged archive contains C++ implementations behind the C API.
        flags: switch (input.config.code.targetOS) {
          OS.linux => ['-lstdc++', '-lm', '-ldl', '-lpthread'],
          OS.macOS || OS.iOS => ['-lc++'],
          OS.android => ['-lc++_static', '-lc++abi', '-lunwind', '-lm', '-ldl'],
          _ => [],
        },
        symbolsToKeep: input.recordedUses?.calls.keys
            .where(
              (definition) =>
                  definition.library.uri ==
                  'package:mujoco/src/backend/native.g.dart',
            )
            .map((definition) => recordUseMapping[definition.name]!),
      ),
    );
  });
}
