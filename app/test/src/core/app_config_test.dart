import 'package:eightup_user_app/src/core/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.parseEnv', () {
    test('parses supported dotenv syntax', () {
      final env = AppConfig.parseEnv('''
# comment
SUPABASE_URL=https://example.supabase.co
export SUPABASE_ANON_KEY="anon-key"
EMPTY=
SINGLE='value'
IGNORED_LINE
''');

      expect(env['SUPABASE_URL'], 'https://example.supabase.co');
      expect(env['SUPABASE_ANON_KEY'], 'anon-key');
      expect(env['EMPTY'], '');
      expect(env['SINGLE'], 'value');
      expect(env.containsKey('IGNORED_LINE'), isFalse);
    });
  });

  group('AppConfig.resolve', () {
    test(
      'uses bundled fallback for release builds when defines are missing',
      () {
        final config = AppConfig.resolve(
          env: const {
            'SUPABASE_URL': 'https://bundle.supabase.co',
            'SUPABASE_ANON_KEY': 'bundle-anon-key',
          },
        );

        expect(config.supabaseUrl, 'https://bundle.supabase.co');
        expect(config.supabaseAnonKey, 'bundle-anon-key');
      },
    );

    test('prefers environment-specific defines over bundled fallback', () {
      final config = AppConfig.resolve(
        appEnv: 'real',
        supabaseUrlRealDefine: 'https://define-real.supabase.co',
        supabaseAnonKeyRealDefine: 'define-real-anon-key',
        env: const {
          'SUPABASE_URL': 'https://bundle.supabase.co',
          'SUPABASE_ANON_KEY': 'bundle-anon-key',
          'SUPABASE_URL_REAL': 'https://bundle-real.supabase.co',
          'SUPABASE_ANON_KEY_REAL': 'bundle-real-anon-key',
        },
      );

      expect(config.supabaseUrl, 'https://define-real.supabase.co');
      expect(config.supabaseAnonKey, 'define-real-anon-key');
    });

    test('can disable bundled fallback explicitly', () {
      final config = AppConfig.resolve(
        env: const {
          'SUPABASE_URL': 'https://bundle.supabase.co',
          'SUPABASE_ANON_KEY': 'bundle-anon-key',
        },
        allowBundledFallback: false,
      );

      expect(config.isValid, isFalse);
    });
  });
}
