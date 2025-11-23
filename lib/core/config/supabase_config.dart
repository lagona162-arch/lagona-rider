import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url {
    final envUrl = dotenv.env['SUPABASE_URL'];
    if (envUrl == null || envUrl.isEmpty) {
      throw Exception(
          'SUPABASE_URL is not set in .env file. Please check your .env configuration.');
    }
    return envUrl;
  }

  static String get anonKey {
    final envKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (envKey == null || envKey.isEmpty) {
      throw Exception(
          'SUPABASE_ANON_KEY is not set in .env file. Please check your .env configuration.');
    }
    return envKey;
  }

  static String get projectId {
    final envProjectId = dotenv.env['SUPABASE_PROJECT_ID'];
    if (envProjectId == null || envProjectId.isEmpty) {
      throw Exception(
          'SUPABASE_PROJECT_ID is not set in .env file. Please check your .env configuration.');
    }
    return envProjectId;
  }
}

