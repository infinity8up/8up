import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  static const _envAssetPath = 'assets/config/runtime.env';
  static const _appEnvDefine = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
  static const _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
  static const _supabaseAnonKeyDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const _supabaseUrlDevDefine = String.fromEnvironment(
    'SUPABASE_URL_DEV',
  );
  static const _supabaseAnonKeyDevDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY_DEV',
  );
  static const _supabaseUrlRealDefine = String.fromEnvironment(
    'SUPABASE_URL_REAL',
  );
  static const _supabaseAnonKeyRealDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY_REAL',
  );

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isValid => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static Future<AppConfig> load() async {
    final env = await _loadEnvAsset();
    return resolve(env: env, allowBundledFallback: !kIsWeb && kReleaseMode);
  }

  static AppConfig resolve({
    Map<String, String> env = const {},
    String appEnv = _appEnvDefine,
    String supabaseUrlDefine = _supabaseUrlDefine,
    String supabaseAnonKeyDefine = _supabaseAnonKeyDefine,
    String supabaseUrlDevDefine = _supabaseUrlDevDefine,
    String supabaseAnonKeyDevDefine = _supabaseAnonKeyDevDefine,
    String supabaseUrlRealDefine = _supabaseUrlRealDefine,
    String supabaseAnonKeyRealDefine = _supabaseAnonKeyRealDefine,
    bool allowBundledFallback = true,
  }) {
    final normalizedAppEnv = appEnv.trim().toLowerCase();
    final useRealEnv =
        normalizedAppEnv == 'real' ||
        normalizedAppEnv == 'prod' ||
        normalizedAppEnv == 'production';
    final bundledEnv = allowBundledFallback ? env : const <String, String>{};

    return AppConfig(
      supabaseUrl: _firstNonEmpty([
        supabaseUrlDefine,
        useRealEnv ? supabaseUrlRealDefine : supabaseUrlDevDefine,
        if (useRealEnv)
          bundledEnv['SUPABASE_URL_REAL']
        else
          bundledEnv['SUPABASE_URL_DEV'],
        bundledEnv['SUPABASE_URL'],
        bundledEnv['SUPABASE_URL_REAL'],
        bundledEnv['SUPABASE_URL_DEV'],
      ]),
      supabaseAnonKey: _firstNonEmpty([
        supabaseAnonKeyDefine,
        useRealEnv ? supabaseAnonKeyRealDefine : supabaseAnonKeyDevDefine,
        if (useRealEnv)
          bundledEnv['SUPABASE_ANON_KEY_REAL']
        else
          bundledEnv['SUPABASE_ANON_KEY_DEV'],
        bundledEnv['SUPABASE_ANON_KEY'],
        bundledEnv['SUPABASE_ANON_KEY_REAL'],
        bundledEnv['SUPABASE_ANON_KEY_DEV'],
      ]),
    );
  }

  static Map<String, String> parseEnv(String rawEnv) {
    final env = <String, String>{};
    for (final rawLine in rawEnv.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }

      final separatorIndex = line.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }

      var key = line.substring(0, separatorIndex).trim();
      if (key.startsWith('export ')) {
        key = key.substring('export '.length).trim();
      }
      if (key.isEmpty) {
        continue;
      }

      var value = line.substring(separatorIndex + 1).trim();
      if (value.length >= 2) {
        final quote = value[0];
        if ((quote == '"' || quote == "'") && value.endsWith(quote)) {
          value = value.substring(1, value.length - 1);
        }
      }

      env[key] = value;
    }
    return env;
  }

  static Future<Map<String, String>> _loadEnvAsset() async {
    try {
      final rawEnv = await rootBundle.loadString(_envAssetPath);
      return parseEnv(rawEnv);
    } catch (_) {
      return const {};
    }
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }
}
