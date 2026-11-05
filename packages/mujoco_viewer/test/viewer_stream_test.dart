import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mujoco/mujoco.dart';
import 'package:mujoco_viewer/mujoco_viewer.dart';

class TestController extends Fake implements MujocoViewerController {
  TestController(this.model);
  @override
  final MjModel model;
  bool disposed = false;
  @override
  void dispose() => disposed = true;
}

void main() {
  late MjModel model;
  late TestController controller;
  setUp(() {
    model = MjModel.from_xml_string('<mujoco/>');
    controller = TestController(model);
  });
  tearDown(() => model.dispose());

  Widget viewer(Stream<MjSceneState> states) => Directionality(
    textDirection: TextDirection.ltr,
    child: MujocoViewer(model: model, states: states, controller: controller),
  );

  testWidgets(
    'Replacing streams cancels the old subscription and clears its error',
    (tester) async {
      var canceled = 0;
      final first = StreamController<MjSceneState>(onCancel: () => canceled++);
      final second = StreamController<MjSceneState>();
      await tester.pumpWidget(viewer(first.stream));
      first.addError(StateError('old producer failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('old producer failed'), findsOneWidget);
      await tester.pumpWidget(viewer(second.stream));
      expect(canceled, 1);
      expect(find.textContaining('old producer failed'), findsNothing);
      second.addError(StateError('new producer failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('new producer failed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(controller.disposed, isFalse);
      unawaited(first.close());
      unawaited(second.close());
    },
  );

  testWidgets(
    'Invalid snapshot layout for the model is reported and unmount cancels listening',
    (tester) async {
      var canceled = false;
      final states = StreamController<MjSceneState>(
        onCancel: () => canceled = true,
      );
      await tester.pumpWidget(viewer(states.stream));
      states.add(
        MjSceneState(
          time: 0,
          positions: [0, 0, 0],
          rotations: [1, 0, 0, 0, 1, 0, 0, 0, 1],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('geom count'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(canceled, isTrue);
      expect(controller.disposed, isFalse);
      unawaited(states.close());
    },
  );
}
