import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App loads admin route', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const RpcApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Choose Match Mode'), findsOneWidget);
  });
}
