import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/supabase/supabase_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Env.isConfigured) {
    await SupabaseClientProvider.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  } else {
    debugPrint(
      'WARNING: Supabase not configured. Pass --dart-define=SUPABASE_URL=... '
      'and --dart-define=SUPABASE_ANON_KEY=... See README.',
    );
  }

  runApp(const EdutimeApp());
}
