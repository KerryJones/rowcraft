import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Watches the Supabase auth state stream.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Current session, derived from the auth state stream.
final currentSessionProvider = Provider<Session?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenOrNull(data: (state) => state.session);
});

/// Current user, derived from the session.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(currentSessionProvider)?.user;
});

/// Whether the user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentSessionProvider) != null;
});

/// Sign in with Google using native SDK + Supabase signInWithIdToken.
final googleSignInProvider = FutureProvider<AuthResponse>((ref) async {
  const clientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  if (clientId.isEmpty) {
    throw StateError(
      'GOOGLE_WEB_CLIENT_ID is not set. '
      'Pass --dart-define=GOOGLE_WEB_CLIENT_ID=... to flutter run/build.',
    );
  }

  final account = await GoogleSignIn.instance.authenticate();

  final idToken = account.authentication.idToken;
  if (idToken == null) throw Exception('No ID token');

  return Supabase.instance.client.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
  );
});

/// Sign out the current user.
final signOutProvider = FutureProvider<void>((ref) async {
  await Supabase.instance.client.auth.signOut();
});
