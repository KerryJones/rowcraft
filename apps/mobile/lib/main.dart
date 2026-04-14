import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/router.dart';
import 'app/theme.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
  );

  const googleClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  if (googleClientId.isNotEmpty) {
    await GoogleSignIn.instance.initialize(serverClientId: googleClientId);
  }

  const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  if (sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2;
        options.attachScreenshot = false;
      },
      appRunner: () {
        FlutterNativeSplash.remove();
        runApp(const ProviderScope(child: RowCraftApp()));
      },
    );
  } else {
    FlutterNativeSplash.remove();
    runApp(const ProviderScope(child: RowCraftApp()));
  }
}

class RowCraftApp extends ConsumerWidget {
  const RowCraftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'RowCraft',
      theme: RowCraftTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
