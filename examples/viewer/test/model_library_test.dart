import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene_lab/model_library.dart';

void main() {
  testWidgets('Selecting another XML updates the highlighted model', (
    tester,
  ) async {
    String? selected = 'a.xml';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ModelLibrary(
              paths: const ['a.xml', 'folder/b.xml'],
              selected: selected,
              busy: false,
              fileCount: 3,
              onDemo: () {},
              onSelected: (path) => setState(() => selected = path),
            ),
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('model:a.xml')))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('folder/b.xml'));
    await tester.pump();
    expect(selected, 'folder/b.xml');
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('model:folder/b.xml')))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('model:a.xml')))
          .selected,
      isFalse,
    );
    expect(find.text('3 imported files'), findsOneWidget);
  });

  testWidgets('Model switching is disabled while an import is in progress', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModelLibrary(
            paths: const ['a.xml'],
            selected: null,
            busy: true,
            fileCount: 1,
            onSelected: (_) => selected = true,
            onDemo: () => selected = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('a.xml'));
    await tester.tap(find.text('Physics lab demo'));
    await tester.pump();
    expect(selected, isFalse);
  });
}
