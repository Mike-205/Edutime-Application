import 'package:firebase_core/firebase_core.dart';
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

  // Firebase powers FCM push. Guarded: without a platform config
  // (google-services.json) this throws — the app still runs, push just stays
  // off and the in-app notification history (DB-backed) keeps working.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase not configured; push disabled: $e');
  }

  runApp(const EdutimeApp());
}
