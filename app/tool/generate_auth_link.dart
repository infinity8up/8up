import 'dart:convert';
import 'dart:io';

const _defaultMobileRedirect = 'eightup://login-callback/';
const _defaultAdminRedirect = 'http://localhost:3000/admin';
const _defaultMemberRedirect = _defaultMobileRedirect;

Future<void> main(List<String> args) async {
  final parsed = _parseArgs(args);
  if (parsed.showHelp) {
    stdout.writeln(_usage);
    exit(0);
  }

  if (parsed.mode == null) {
    stderr.writeln('Mode is required.\n');
    stderr.writeln(_usage);
    exit(64);
  }

  final env = _loadEnv();
  final supabaseUrl =
      parsed.option('supabase-url') ?? env['SUPABASE_URL'] ?? '';
  final serviceRoleKey =
      parsed.option('service-role-key') ??
      env['SUPABASE_SERVICE_ROLE_KEY'] ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'] ??
      '';

  if (supabaseUrl.isEmpty || serviceRoleKey.isEmpty) {
    stderr.writeln(
      'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required. '
      'Use app/.env and environment variables or pass them explicitly.',
    );
    exit(64);
  }

  final client = _SupabaseAdminClient(
    baseUrl: supabaseUrl,
    serviceRoleKey: serviceRoleKey,
  );

  try {
    switch (parsed.mode!) {
      case 'member-signup':
        await _generateMemberSignupLink(client, parsed);
        break;
      case 'admin-signup':
        await _generateAdminSignupLink(client, parsed);
        break;
      case 'member-recovery':
        await _generateMemberRecoveryLink(client, parsed);
        break;
      case 'admin-recovery':
        await _generateAdminRecoveryLink(client, parsed);
        break;
      default:
        stderr.writeln('Unsupported mode: ${parsed.mode}');
        exit(64);
    }
  } on _CliException catch (error) {
    stderr.writeln(error.message);
    exit(error.exitCode);
  }
}

Future<void> _generateMemberSignupLink(
  _SupabaseAdminClient client,
  _ParsedArgs args,
) async {
  final email = _requireOption(args, 'email').toLowerCase();
  final password = _requireOption(args, 'password');
  final name = _requireOption(args, 'name');
  final loginId = args.option('login-id')?.toLowerCase();
  final redirectTo = args.option('redirect') ?? _defaultMemberRedirect;

  final response = await client.generateLink(
    type: 'signup',
    email: email,
    password: password,
    redirectTo: redirectTo,
    data: {
      'name': name,
      'account_type': 'member',
      if (loginId != null && loginId.isNotEmpty) 'login_id': loginId,
    },
  );

  _printResponse(
    title: 'Member signup link generated',
    actionLink: response.actionLink,
    emailOtp: response.emailOtp,
    hashedToken: response.hashedToken,
    email: email,
    redirectTo: redirectTo,
  );
}

Future<void> _generateAdminSignupLink(
  _SupabaseAdminClient client,
  _ParsedArgs args,
) async {
  final studioName = _requireOption(args, 'studio-name');
  final studioPhone = _requireOption(args, 'studio-phone');
  final studioAddress = _requireOption(args, 'studio-address');
  final adminName = _requireOption(args, 'admin-name');
  final loginId = _requireOption(args, 'login-id').toLowerCase();
  final email = _requireOption(args, 'email').toLowerCase();
  final password = _requireOption(args, 'password');
  final redirectTo = args.option('redirect') ?? _defaultAdminRedirect;

  await client.rpc('validate_admin_signup_request', {
    'p_studio_name': studioName,
    'p_login_id': loginId,
    'p_email': email,
  });

  final response = await client.generateLink(
    type: 'signup',
    email: email,
    password: password,
    redirectTo: redirectTo,
    data: {
      'name': adminName,
      'account_type': 'admin_pending',
      'studio_name': studioName,
      'studio_phone': studioPhone,
      'studio_address': studioAddress,
      'admin_login_id': loginId,
      'admin_role': 'admin',
    },
  );

  _printResponse(
    title: 'Admin signup link generated',
    actionLink: response.actionLink,
    emailOtp: response.emailOtp,
    hashedToken: response.hashedToken,
    email: email,
    redirectTo: redirectTo,
  );
}

Future<void> _generateMemberRecoveryLink(
  _SupabaseAdminClient client,
  _ParsedArgs args,
) async {
  final identifier = _requireOption(args, 'identifier');
  final email = _requireOption(args, 'email').toLowerCase();
  final redirectTo = args.option('redirect') ?? _defaultMemberRedirect;

  final resolvedEmail = await client.rpc('resolve_user_password_reset_email', {
    'p_identifier': identifier,
    'p_email': email,
  });

  if (resolvedEmail is! String || resolvedEmail.isEmpty) {
    throw const _CliException('입력한 회원 ID와 이메일이 일치하는 회원을 찾을 수 없습니다.');
  }

  final response = await client.generateLink(
    type: 'recovery',
    email: resolvedEmail,
    redirectTo: redirectTo,
  );

  _printResponse(
    title: 'Member recovery link generated',
    actionLink: response.actionLink,
    emailOtp: response.emailOtp,
    hashedToken: response.hashedToken,
    email: resolvedEmail,
    redirectTo: redirectTo,
  );
}

Future<void> _generateAdminRecoveryLink(
  _SupabaseAdminClient client,
  _ParsedArgs args,
) async {
  final identifier = _requireOption(args, 'identifier');
  final email = _requireOption(args, 'email').toLowerCase();
  final redirectTo = args.option('redirect') ?? _defaultAdminRedirect;

  final resolvedEmail = await client.rpc('resolve_admin_password_reset_email', {
    'p_identifier': identifier,
    'p_email': email,
  });

  if (resolvedEmail is! String || resolvedEmail.isEmpty) {
    throw const _CliException('입력한 관리자 ID와 이메일이 일치하는 계정을 찾을 수 없습니다.');
  }

  final response = await client.generateLink(
    type: 'recovery',
    email: resolvedEmail,
    redirectTo: redirectTo,
  );

  _printResponse(
    title: 'Admin recovery link generated',
    actionLink: response.actionLink,
    emailOtp: response.emailOtp,
    hashedToken: response.hashedToken,
    email: resolvedEmail,
    redirectTo: redirectTo,
  );
}

String _requireOption(_ParsedArgs args, String name) {
  final value = args.option(name)?.trim();
  if (value == null || value.isEmpty) {
    throw _CliException('Missing required option: --$name', exitCode: 64);
  }
  return value;
}

void _printResponse({
  required String title,
  required String actionLink,
  required String? emailOtp,
  required String? hashedToken,
  required String email,
  required String redirectTo,
}) {
  stdout.writeln(title);
  stdout.writeln('email: $email');
  stdout.writeln('redirect: $redirectTo');
  stdout.writeln('action_link: $actionLink');
  if (emailOtp != null && emailOtp.isNotEmpty) {
    stdout.writeln('email_otp: $emailOtp');
  }
  if (hashedToken != null && hashedToken.isNotEmpty) {
    stdout.writeln('hashed_token: $hashedToken');
  }
}

Map<String, String> _loadEnv() {
  final env = <String, String>{};
  for (final path in const ['.env', 'app/.env']) {
    final file = File(path);
    if (!file.existsSync()) {
      continue;
    }
    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final separator = line.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      final key = line.substring(0, separator).trim();
      var value = line.substring(separator + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      env[key] = value;
    }
  }
  return env;
}

class _SupabaseAdminClient {
  _SupabaseAdminClient({required this.baseUrl, required this.serviceRoleKey});

  final String baseUrl;
  final String serviceRoleKey;

  Future<Object?> rpc(String functionName, Map<String, Object?> params) async {
    final uri = Uri.parse('$baseUrl/rest/v1/rpc/$functionName');
    final request = await HttpClient().postUrl(uri);
    try {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('apikey', serviceRoleKey);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $serviceRoleKey',
      );
      request.add(utf8.encode(jsonEncode(params)));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (body.isEmpty) {
          return null;
        }
        return jsonDecode(body);
      }
      throw _CliException(_extractError(body), exitCode: response.statusCode);
    } finally {
      request.abort();
    }
  }

  Future<_GenerateLinkResult> generateLink({
    required String type,
    required String email,
    String? password,
    String? redirectTo,
    Map<String, Object?>? data,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/v1/admin/generate_link');
    final request = await HttpClient().postUrl(uri);
    try {
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.headers.set('apikey', serviceRoleKey);
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $serviceRoleKey',
      );
      request.add(
        utf8.encode(
          jsonEncode({
            'type': type,
            'email': email,
            if (password != null && password.isNotEmpty) 'password': password,
            if (redirectTo != null && redirectTo.isNotEmpty)
              'redirect_to': redirectTo,
            if (data != null && data.isNotEmpty) 'data': data,
          }),
        ),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _CliException(_extractError(body), exitCode: response.statusCode);
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const _CliException('Unexpected generate_link response');
      }

      return _GenerateLinkResult(
        actionLink: decoded['action_link'] as String? ?? '',
        emailOtp: decoded['email_otp'] as String?,
        hashedToken: decoded['hashed_token'] as String?,
      );
    } finally {
      request.abort();
    }
  }
}

class _GenerateLinkResult {
  const _GenerateLinkResult({
    required this.actionLink,
    required this.emailOtp,
    required this.hashedToken,
  });

  final String actionLink;
  final String? emailOtp;
  final String? hashedToken;
}

class _ParsedArgs {
  _ParsedArgs(this.mode, this._options, this.showHelp);

  final String? mode;
  final Map<String, String> _options;
  final bool showHelp;

  String? option(String key) => _options[key];
}

_ParsedArgs _parseArgs(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    return _ParsedArgs(null, const {}, true);
  }

  final options = <String, String>{};
  String? mode;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--') && mode == null) {
      mode = arg;
      continue;
    }
    if (!arg.startsWith('--')) {
      throw _CliException('Unexpected argument: $arg', exitCode: 64);
    }
    final key = arg.substring(2);
    if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
      throw _CliException('Missing value for --$key', exitCode: 64);
    }
    options[key] = args[i + 1];
    i += 1;
  }

  return _ParsedArgs(mode, options, false);
}

String _extractError(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final message =
          decoded['msg'] ?? decoded['message'] ?? decoded['error_description'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      final error = decoded['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
  } catch (_) {}
  return body.isEmpty ? 'Request failed' : body;
}

class _CliException implements Exception {
  const _CliException(this.message, {this.exitCode = 1});

  final String message;
  final int exitCode;
}

const _usage = '''
Usage:
  dart run tool/generate_auth_link.dart <mode> [options]

Modes:
  member-signup
  admin-signup
  member-recovery
  admin-recovery

Common options:
  --supabase-url <url>
  --service-role-key <key>
  --redirect <url>

member-signup:
  --name <name>
  --email <email>
  --password <password>
  [--login-id <loginId>]

admin-signup:
  --studio-name <name>
  --studio-phone <phone>
  --studio-address <address>
  --admin-name <name>
  --login-id <loginId>
  --email <email>
  --password <password>

member-recovery:
  --identifier <memberCodeOrLoginIdOrEmail>
  --email <email>

admin-recovery:
  --identifier <adminLoginIdOrEmail>
  --email <email>

Examples:
  dart run tool/generate_auth_link.dart member-signup --name "Tester" --email "tester@example.com" --password "test1234"
  dart run tool/generate_auth_link.dart admin-signup --studio-name "Seoul Ballet" --studio-phone "02-0000-0000" --studio-address "Seoul" --admin-name "Manager" --login-id "seoul_manager" --email "manager@example.com" --password "Manager123!"
  dart run tool/generate_auth_link.dart member-recovery --identifier "abc12" --email "tester@example.com"
  dart run tool/generate_auth_link.dart admin-recovery --identifier "seoul_manager" --email "manager@example.com"
''';
