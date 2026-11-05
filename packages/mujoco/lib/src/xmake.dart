import 'package:native_toolchain_xmake/native_toolchain_xmake.dart';

final xmakeLibrary = XmakeLibrary(
  target: 'mujoco_dart',
  libHintName: 'mujoco',
  assetName: 'src/backend/native.g.dart',
);
