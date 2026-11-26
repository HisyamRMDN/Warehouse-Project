import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://cgnayblbwoivcoahrijy.supabase.co';
  static const String supabasePublishableKey =
      'sb_publishable_Wdo8zEOZIlORaJZyKyaQ5w_V96o82Gx';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }
}

final supabase = Supabase.instance.client;
