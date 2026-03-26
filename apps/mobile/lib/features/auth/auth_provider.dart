import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Sign in with email and password.
final signInProvider =
    FutureProvider.family<AuthResponse, ({String email, String password})>(
  (ref, credentials) async {
    return Supabase.instance.client.auth.signInWithPassword(
      email: credentials.email,
      password: credentials.password,
    );
  },
);

/// Sign up with email and password.
final signUpProvider =
    FutureProvider.family<AuthResponse, ({String email, String password})>(
  (ref, credentials) async {
    return Supabase.instance.client.auth.signUp(
      email: credentials.email,
      password: credentials.password,
    );
  },
);

/// Sign in with Google OAuth.
/// Uses a custom deep link to redirect back to the app after auth.
final googleSignInProvider = FutureProvider<bool>((ref) async {
  final success = await Supabase.instance.client.auth.signInWithOAuth(
    OAuthProvider.google,
    redirectTo: 'com.rowcraft.app://login-callback',
  );
  return success;
});

/// Sign out the current user.
final signOutProvider = FutureProvider<void>((ref) async {
  await Supabase.instance.client.auth.signOut();
});
