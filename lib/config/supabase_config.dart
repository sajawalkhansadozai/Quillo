// ─────────────────────────────────────────────────────────────────────────────
// Quillo — App Configuration
// Google Cloud Project: quillo-494112
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseConfig {
  // ── Supabase ──────────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://klvzgfheneyqrwfxtfyg.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtsdnpnZmhlbmV5cXJ3Znh0ZnlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNDQ2NjYsImV4cCI6MjA5MTkyMDY2Nn0.O3EeMUV0E-Eu5MLYj5wNmCWIALfr3kHk_MZLhz1nlPA';

  // ── Google Sign-In ────────────────────────────────────────────────────────
  // iOS OAuth 2.0 Client ID (from Google Cloud Console → iOS type)
  static const String googleIosClientId =
      '1095833940103-ht1miba38u48pu11939o9i0uprl8dkar.apps.googleusercontent.com';

  // Android OAuth 2.0 Client ID (from Google Cloud Console → Android type)
  static const String googleAndroidClientId =
      '1095833940103-g2c420ni7ec2kqb3q4vri4s6pts2mkb2.apps.googleusercontent.com';
}
