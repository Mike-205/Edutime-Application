// Smoke test: with no Supabase config (no --dart-define), the app boots to the
// setup-required screen instead of crashing. Auth-flow and authenticated-screen
// tests (which require a mocked Supabase client) live in the testing milestone.

import 'package:edutime/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App boots to the setup-required screen when unconfigured', (
    tester,
  ) async {
    await tester.pumpWidget(const EdutimeApp());

    expect(find.textContaining('Supabase is not configured'), findsOneWidget);
  });
}
