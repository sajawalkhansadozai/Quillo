import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../utils/cooking_skill_labels.dart';
import 'analytics_service.dart';
import 'local_db_service.dart';
import 'onboarding_router.dart';
import 'subscription_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AuthResult — returned by every auth method
// ─────────────────────────────────────────────────────────────────────────────

class AuthResult {
  final bool success;
  final String? error;
  final bool needsEmailVerification;

  const AuthResult({
    required this.success,
    this.error,
    this.needsEmailVerification = false,
  });

  factory AuthResult.ok() => const AuthResult(success: true);
  factory AuthResult.verifyEmail() =>
      const AuthResult(success: false, needsEmailVerification: true);
  factory AuthResult.err(String message) =>
      AuthResult(success: false, error: message);
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthService
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  static final _client = Supabase.instance.client;

  // ── Current session ────────────────────────────────────────────────────────

  static User? get currentUser => _client.auth.currentUser;
  static bool get isSignedIn => currentUser != null;

  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // ── Email / Password ───────────────────────────────────────────────────────

  static Future<AuthResult> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: SupabaseConfig.emailConfirmRedirectUrl,
        data: fullName != null && fullName.isNotEmpty
            ? {'full_name': fullName}
            : null,
      );
      if (res.user != null && res.session == null) {
        return AuthResult.verifyEmail();
      }
      if (res.session != null) {
        await SubscriptionService.linkUserAfterAuth();
      }
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.err(_friendlyError(e.message));
    } catch (e) {
      return AuthResult.err('Something went wrong. Please try again.');
    }
  }

  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      await SubscriptionService.linkUserAfterAuth();
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.err(_friendlyError(e.message));
    } catch (e) {
      return AuthResult.err('Something went wrong. Please try again.');
    }
  }

  static Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: SupabaseConfig.emailConfirmRedirectUrl,
      );
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.err(_friendlyError(e.message));
    } catch (e) {
      return AuthResult.err('Something went wrong. Please try again.');
    }
  }

  // ── Google ─────────────────────────────────────────────────────────────────

  static Future<AuthResult> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        clientId: defaultTargetPlatform == TargetPlatform.iOS
            ? SupabaseConfig.googleIosClientId
            : SupabaseConfig.googleAndroidClientId,
        serverClientId: SupabaseConfig.googleWebClientId,
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.err('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        return AuthResult.err('Could not retrieve Google credentials.');
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      await SubscriptionService.linkUserAfterAuth();
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.err(_friendlyError(e.message));
    } catch (e) {
      return AuthResult.err('Google sign-in failed. Please try again.');
    }
  }

  // ── Apple ──────────────────────────────────────────────────────────────────

  static Future<AuthResult> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return AuthResult.err('Could not retrieve Apple credentials.');
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );

      await SubscriptionService.linkUserAfterAuth();
      return AuthResult.ok();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.err('Apple sign-in was cancelled.');
      }
      return AuthResult.err('Apple sign-in failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.err(_friendlyError(e.message));
    } catch (e) {
      return AuthResult.err('Apple sign-in failed. Please try again.');
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  static Future<void> signOut() async {
    await SubscriptionService.logOut();
    await AnalyticsService.reset();
    await OnboardingRouter.clearLocalOnboardingPrefs();
    await _client.auth.signOut();
  }

  /// Permanently deletes the signed-in account and associated server data.
  /// BlindSpots 6.2 — must actually purge, not just show a snackbar.
  static Future<AuthResult> deleteAccount() async {
    final user = currentUser;
    if (user == null) {
      return AuthResult.err('You must be signed in to delete your account.');
    }

    try {
      await SubscriptionService.logOut();
    } catch (_) {
      // Continue — account delete must not fail solely on RevenueCat logout.
    }

    try {
      final response = await _client.functions.invoke('delete-account');
      final data = response.data;
      Map<String, dynamic>? map;
      if (data is Map<String, dynamic>) {
        map = data;
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      }

      if (response.status != 200) {
        final msg = map?['error'] as String? ??
            'Could not delete account. Please try again.';
        return AuthResult.err(msg);
      }

      try {
        await LocalDbService.clearAllUserData();
      } catch (_) {}

      try {
        await _client.auth.signOut();
      } catch (_) {
        // Session may already be invalid after server-side delete.
      }

      return AuthResult.ok();
    } on FunctionException catch (e) {
      final details = e.details;
      String msg = 'Could not delete account. Please try again.';
      if (details is Map && details['error'] is String) {
        msg = details['error'] as String;
      }
      return AuthResult.err(msg);
    } catch (_) {
      return AuthResult.err(
        'Could not delete account. Check your connection and try again.',
      );
    }
  }

  // ── User profile upsert ────────────────────────────────────────────────────

  static Future<void> saveUserProfile({
    int? householdSize,
    List<String>? preferredCuisines,
    List<String>? dietaryLabels,
    bool? gdprConsent,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    final data = <String, dynamic>{'id': uid};
    if (householdSize != null) data['household_size'] = householdSize;
    if (preferredCuisines != null) data['preferred_cuisine'] = preferredCuisines;
    if (gdprConsent != null) {
      data['gdpr_consent'] = gdprConsent;
      data['gdpr_consent_at'] = DateTime.now().toIso8601String();
    }
    try {
      await _client.from('users').upsert(data);
    } catch (_) {
      // Profile save is best-effort — auth already succeeded
    }
  }

  /// Called once after account creation or first SSO login.
  /// Seeds the users row with email, GDPR consent, and default values.
  static Future<void> initUserProfile({
    required String email,
    String fullName = '',
    bool gdprConsent = false,
    int householdSize = 2,
    List<String> preferredCuisines = const [],
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await _client.from('users').upsert({
        'id': uid,
        'email': email,
        if (fullName.isNotEmpty) 'full_name': fullName,
        'subscription_status': 'free',
        'scan_streak': 0,
        'household_size': householdSize,
        'preferred_cuisine': preferredCuisines,
        'gdpr_consent': gdprConsent,
        if (gdprConsent) 'gdpr_consent_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Saves dietary labels and cooking constraints to user_preferences.
  /// Only provided fields are written (null/omitted = leave existing).
  static Future<void> saveUserPreferences({
    List<String>? dietaryLabels,
    List<String>? excludeIngredients,
    String? cookingSkill,
    int? maxCookTimeMinutes,
    bool? onboardingCompleted,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      final payload = <String, dynamic>{
        'user_id': uid,
        if (dietaryLabels != null) 'dietary_labels': dietaryLabels,
        if (excludeIngredients != null) 'exclude_ingredients': excludeIngredients,
        if (cookingSkill != null && cookingSkill.isNotEmpty)
          'cooking_skill': cookingSkill,
        if (maxCookTimeMinutes != null && maxCookTimeMinutes > 0)
          'max_cook_time': maxCookTimeMinutes,
        if (onboardingCompleted != null)
          'onboarding_completed': onboardingCompleted,
      };
      await _client.from('user_preferences').upsert(
        payload,
        onConflict: 'user_id',
      );
    } catch (_) {}
  }

  /// §2.2 — true only when [user_preferences.onboarding_completed] is true.
  static Future<bool> hasCompletedOnboarding() async {
    final uid = currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await _client
          .from('user_preferences')
          .select('onboarding_completed')
          .eq('user_id', uid)
          .maybeSingle();
      return isOnboardingCompletedFlag(row?['onboarding_completed']);
    } catch (_) {
      return false;
    }
  }

  /// Pure helper for tests / routing — null/false/missing ⇒ not complete.
  static bool isOnboardingCompletedFlag(Object? value) => value == true;

  /// §2.4–2.5 — write all onboarding prefs + set completed=true in one finish step.
  /// Does not wipe recipes / scans / waste — only preference fields.
  static Future<void> completeOnboardingFromLocalPrefs() async {
    final uid = currentUser?.id;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final gdprConsent = prefs.getBool('gdpr_analytics') ?? false;
    final householdSize = prefs.getInt('onboarding_household_size') ?? 2;
    final dietary = prefs.getStringList('onboarding_dietary') ?? [];
    final cuisines = prefs.getStringList('onboarding_cuisines') ?? [];
    final skillRaw = prefs.getString('onboarding_skill_level') ?? 'Home Cook';
    final maxCookTime = prefs.getInt('onboarding_max_cook_time') ?? 45;
    final cookingSkill = CookingSkillLabels.normalize(skillRaw);
    final email = currentUser?.email ?? '';
    final fullName =
        (currentUser?.userMetadata?['full_name'] as String?)?.trim() ?? '';

    await initUserProfile(
      email: email,
      fullName: fullName,
      gdprConsent: gdprConsent,
      householdSize: householdSize,
      preferredCuisines: cuisines,
    );
    await saveUserPreferences(
      dietaryLabels: dietary,
      cookingSkill: cookingSkill,
      maxCookTimeMinutes: maxCookTime,
      onboardingCompleted: true,
    );
  }

  /// Updates the signed-in user's password.
  static Future<AuthResult> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return AuthResult.ok();
    } on AuthException catch (e) {
      return AuthResult.err(_friendlyError(e.message));
    } catch (e) {
      return AuthResult.err('Failed to update password. Please try again.');
    }
  }

  /// Returns true if this is the first sign-in for the current user
  /// (i.e. no row exists yet in the users table).
  static Future<bool> isNewUser() async {
    final uid = currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await _client
          .from('users')
          .select('id')
          .eq('id', uid)
          .maybeSingle();
      return row == null;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login') || lower.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('password should be')) {
      return 'Password must be at least 6 characters.';
    }
    if (lower.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    return raw;
  }
}
