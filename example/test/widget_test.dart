// Basic smoke test for the zennopay_flutter example host app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zennopay_flutter_example/main.dart';

void main() {
  testWidgets('renders the Pay button', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());

    expect(find.text('Pay with Zennopay'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });
}
