import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin/admin_web_app.dart';
import '../core/app_colors.dart';
import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../presentation/screens/root_shell.dart';
import '../presentation/widgets/common_widgets.dart';
import '../providers/app_settings_controller.dart';
import '../providers/auth_controller.dart';
import '../providers/calendar_controller.dart';
import '../providers/notifications_controller.dart';
import '../providers/push_notifications_controller.dart';
import '../providers/studio_controller.dart';
import '../providers/passes_controller.dart';
import '../providers/reservations_controller.dart';
import '../providers/user_context_controller.dart';
import '../repositories/studio_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/image_storage_repository.dart';
import '../repositories/pass_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/push_notification_repository.dart';
import '../repositories/reservation_repository.dart';
import '../repositories/session_repository.dart';
import '../repositories/app_settings_repository.dart';

class EightUpApp extends StatelessWidget {
  const EightUpApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const EightUpAdminWebApp();
    }

    return MultiProvider(
      providers: [
        Provider.value(value: config),
        Provider<SupabaseClient>(create: (_) => Supabase.instance.client),
        ProxyProvider<SupabaseClient, ImageStorageRepository>(
          update: (_, client, __) => ImageStorageRepository(client),
        ),
        ProxyProvider<SupabaseClient, AuthRepository>(
          update: (_, client, __) => AuthRepository(client),
        ),
        ProxyProvider2<
          SupabaseClient,
          ImageStorageRepository,
          ProfileRepository
        >(
          update: (_, client, imageStorage, __) =>
              ProfileRepository(client, imageStorage),
        ),
        ProxyProvider<SupabaseClient, StudioRepository>(
          update: (_, client, __) => StudioRepository(client),
        ),
        ProxyProvider<SupabaseClient, PassRepository>(
          update: (_, client, __) => PassRepository(client),
        ),
        ProxyProvider<SupabaseClient, ReservationRepository>(
          update: (_, client, __) => ReservationRepository(client),
        ),
        ProxyProvider<SupabaseClient, NotificationRepository>(
          update: (_, client, __) => NotificationRepository(client),
        ),
        ProxyProvider<SupabaseClient, PushNotificationRepository>(
          update: (_, client, __) => PushNotificationRepository(client),
        ),
        ProxyProvider<SupabaseClient, SessionRepository>(
          update: (_, client, __) => SessionRepository(client),
        ),
        Provider<AppSettingsRepository>(create: (_) => AppSettingsRepository()),
        ChangeNotifierProvider<AppSettingsController>(
          create: (context) {
            final controller = AppSettingsController(
              context.read<AppSettingsRepository>(),
            );
            controller.load();
            return controller;
          },
        ),
        ChangeNotifierProvider<AuthController>(
          create: (context) => AuthController(context.read<AuthRepository>()),
        ),
        ChangeNotifierProxyProvider4<
          AuthController,
          ProfileRepository,
          StudioRepository,
          AppSettingsRepository,
          UserContextController
        >(
          create: (context) => UserContextController(
            context.read<ProfileRepository>(),
            context.read<StudioRepository>(),
            context.read<AppSettingsRepository>(),
          ),
          update:
              (
                _,
                auth,
                profileRepository,
                studioRepository,
                appSettingsRepository,
                controller,
              ) {
                final resolved =
                    controller ??
                    UserContextController(
                      profileRepository,
                      studioRepository,
                      appSettingsRepository,
                    );
                resolved.bindAuth(auth);
                return resolved;
              },
        ),
        ChangeNotifierProxyProvider2<
          UserContextController,
          StudioRepository,
          StudioController
        >(
          create: (context) =>
              StudioController(context.read<StudioRepository>()),
          update: (_, userContext, repository, controller) {
            final resolved = controller ?? StudioController(repository);
            resolved.bindStudio(userContext.selectedStudioId);
            return resolved;
          },
        ),
        ChangeNotifierProxyProvider2<
          UserContextController,
          PassRepository,
          PassesController
        >(
          create: (context) => PassesController(context.read<PassRepository>()),
          update: (_, userContext, repository, controller) {
            final resolved = controller ?? PassesController(repository);
            resolved.bindStudio(userContext.selectedStudioId);
            return resolved;
          },
        ),
        ChangeNotifierProxyProvider2<
          UserContextController,
          SessionRepository,
          CalendarController
        >(
          create: (context) =>
              CalendarController(context.read<SessionRepository>()),
          update: (_, userContext, repository, controller) {
            final resolved = controller ?? CalendarController(repository);
            resolved.bindStudio(userContext.selectedStudioId);
            return resolved;
          },
        ),
        ChangeNotifierProxyProvider2<
          UserContextController,
          ReservationRepository,
          ReservationsController
        >(
          create: (context) =>
              ReservationsController(context.read<ReservationRepository>()),
          update: (_, userContext, repository, controller) {
            final resolved = controller ?? ReservationsController(repository);
            resolved.bindStudio(userContext.selectedStudioId);
            return resolved;
          },
        ),
        ChangeNotifierProxyProvider4<
          AuthController,
          UserContextController,
          AppSettingsController,
          NotificationRepository,
          NotificationsController
        >(
          create: (context) =>
              NotificationsController(context.read<NotificationRepository>()),
          update: (_, auth, userContext, settings, repository, controller) {
            final resolved = controller ?? NotificationsController(repository);
            resolved.bind(
              userId: auth.userId,
              studioId: userContext.selectedStudioId,
              enabled: true,
            );
            return resolved;
          },
        ),
        ChangeNotifierProxyProvider4<
          AuthController,
          AppSettingsController,
          PushNotificationRepository,
          AppSettingsRepository,
          PushNotificationsController
        >(
          create: (context) => PushNotificationsController(
            context.read<PushNotificationRepository>(),
            context.read<AppSettingsRepository>(),
          ),
          update:
              (
                _,
                auth,
                settings,
                repository,
                appSettingsRepository,
                controller,
              ) {
                final resolved =
                    controller ??
                    PushNotificationsController(
                      repository,
                      appSettingsRepository,
                    );
                resolved.bind(
                  userId: auth.userId,
                  enabled: settings.pushNotificationsEnabled,
                );
                return resolved;
              },
        ),
      ],
      child: MaterialApp(
        title: '8UP',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        locale: const Locale('ko', 'KR'),
        supportedLocales: const [Locale('ko', 'KR'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const RootShell(),
      ),
    );
  }
}

class EightUpConfigMissingApp extends StatelessWidget {
  const EightUpConfigMissingApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      title: '8UP',
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            children: [
              AppViewport(
                maxWidth: 720,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supabase 설정이 필요합니다',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '`--dart-define=SUPABASE_URL=...` 와 '
                          '`--dart-define=SUPABASE_ANON_KEY=...`를 넘기거나, '
                          '`APP_ENV`와 함께 `SUPABASE_URL_DEV`, '
                          '`SUPABASE_ANON_KEY_DEV`, `SUPABASE_URL_REAL`, '
                          '`SUPABASE_ANON_KEY_REAL` 중 맞는 값을 넘겨야 합니다.',
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '현재 URL 길이: ${config.supabaseUrl.length}, '
                          'Anon Key 길이: ${config.supabaseAnonKey.length}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
