import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_design_system/studio_design_system.dart';

// 设计系统组件测试，确保包级基础组件能独立渲染。
void main() {
  testWidgets('status pill renders label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark(),
        home: const StatusPill(
          label: 'Device Ready',
          tone: StudioStatusTone.ready,
        ),
      ),
    );

    expect(find.text('Device Ready'), findsOneWidget);
  });

  testWidgets('studio surface renders child content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark(),
        home: const StudioSurface(child: Text('主面板')),
      ),
    );

    expect(find.text('主面板'), findsOneWidget);
    expect(find.byType(DecoratedBox), findsOneWidget);
  });

  testWidgets('studio inset surface supports fixed width', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark(),
        home: const Center(
          child: StudioInsetSurface(
            key: Key('inset-surface'),
            width: 180,
            child: Text('内嵌'),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byKey(const Key('inset-surface')));
    expect(size.width, 180);
    expect(find.text('内嵌'), findsOneWidget);
  });
}
