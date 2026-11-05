import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:mujoco/src/xmake.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      await xmakeLibrary.build(input: input, output: output);
      output.dependencies.addAll([
        input.packageRoot.resolve('xmake.lua'),
        input.packageRoot.resolve('xmake-requires.lock'),
        input.packageRoot.resolve('xmake_repo/packages/m/mujoco/xmake.lua'),
      ]);
    }
  });
}
