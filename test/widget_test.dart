// Smoke test: the app boots to the schedule screen with its empty state.

import 'package:edutime/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots to the schedule screen', (tester) async {
    await tester.pumpWidget(const EdutimeApp());

    expect(find.text('My schedule'), findsOneWidget);
    expect(find.text('No lectures yet for the selected day.'), findsOneWidget);
  });
}
