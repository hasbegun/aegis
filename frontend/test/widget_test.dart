// This is a basic Flutter widget test for Innox Security

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:innox_security/main.dart';

void main() {
  testWidgets('App starts and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: InnoxSecurityApp()));

    // Verify that the app bar shows Innox Security
    expect(find.text('Innox Security'), findsOneWidget);

    // Verify welcome card is present
    expect(find.text('LLM Vulnerability Scanner'), findsOneWidget);
  });
}
