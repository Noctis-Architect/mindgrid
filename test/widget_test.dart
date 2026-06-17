import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindgrid/theme/app_theme.dart';

void main() {
  testWidgets('dark theme builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Text('How can I help you?'),
        ),
      ),
    );
    expect(find.text('How can I help you?'), findsOneWidget);
  });
}
