import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/router.dart';
import 'app/sync_lifecycle.dart';
import 'app/theme.dart';
import 'widgets/debug_build_banner.dart';

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
        _wireSentryUserScope();
        FlutterNativeSplash.remove();
        runApp(const ProviderScope(child: RowCraftApp()));
      },
    );
  } else {
    FlutterNativeSplash.remove();
    runApp(const ProviderScope(child: RowCraftApp()));
  }
}

/// Tag every Sentry event with the current Supabase user id so failures
/// can be attributed to a specific tester. No-op if Sentry isn't enabled.
void _wireSentryUserScope() {
  final auth = Supabase.instance.client.auth;
  final initial = auth.currentUser;
  if (initial != null) {
    Sentry.configureScope(
      (scope) => scope.setUser(SentryUser(id: initial.id)),
    );
  }
  auth.onAuthStateChange.listen((state) {
    final user = state.session?.user;
    Sentry.configureScope((scope) {
      scope.setUser(user == null ? null : SentryUser(id: user.id));
    });
  });
}

class RowCraftApp extends ConsumerWidget {
  const RowCraftApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return SyncLifecycleObserver(
      child: MaterialApp.router(
        title: 'RowCraft',
        theme: RowCraftTheme.dark,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            DebugBuildBanner(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
