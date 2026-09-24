import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/deeplink/deep_link.dart';
import 'core/push/push_service.dart';
import 'core/session/session_cubit.dart';
import 'core/session/session_store.dart';
import 'core/utils/roots/app_router.dart';
import 'core/utils/services/local_services/cache_helper.dart';
import 'core/utils/services/local_services/cache_keys.dart';
import 'core/utils/services/remote_services/service_locator.dart';
import 'core/utils/theme/app_theme.dart';
import 'core/workspace/workspace.dart';
import 'core/workspace/workspace_cubit.dart';
import 'core/workspace/workspace_state.dart';
import 'features/shared/notifications/presentation/view_models/notifications_cubit.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationDetails _androidChannel = AndroidNotificationDetails(
  'dtp_channel_id',
  'DigitalTradePortal',
  channelDescription: 'dtp_channel_description',
  importance: Importance.max,
  priority: Priority.high,
  icon: 'notification_icon',
  colorized: true,
  color: Color(0xFF1E56A0),
);

const NotificationDetails _notificationDetails = NotificationDetails(
  android: _androidChannel,
  iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // iOS renders notification-payload messages itself; only data-only messages
  // need a local notification.
  if (message.notification == null) _showDataNotification(message);
}

void _showDataNotification(RemoteMessage message) {
  final title = message.data['title'];
  final body = message.data['body'];
  if (title == null && body == null) return;
  flutterLocalNotificationsPlugin.show(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    notificationDetails: _notificationDetails,
    // Carry the routing keys through, so a tap on a locally-rendered
    // notification deep-links exactly like a tap on a system one.
    payload: jsonEncode(message.data),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await CacheHelper.init();

  // Arabic is the server's default and the app's; only an explicit choice
  // changes it.
  if (CacheHelper.getData(key: CacheKeys.language) == null) {
    await CacheHelper.saveData(key: CacheKeys.language, value: 'ar');
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // The locator comes first: the notification handlers reach into it.
  await setup();
  await _initNotifications();

  // Cold start: fetch the device token, then restore the session and
  // bootstrap. Registration with both token tables happens once bootstrap
  // resolves an organization.
  await getIt<PushService>().initialize();
  unawaited(getIt<PushService>().attachTapHandlers());
  unawaited(getIt<SessionCubit>().start());

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      saveLocale: true,
      startLocale: Locale(getIt<SessionStore>().locale),
      fallbackLocale: const Locale('ar'),
      path: 'lib/core/language',
      child: const DigitalTradePortal(),
    ),
  );
}

Future<void> _initNotifications() async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('notification_icon'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (response) {
      final payload = response.payload;
      if (payload == null || payload.isEmpty) return;
      try {
        final data = (jsonDecode(payload) as Map).cast<String, dynamic>();
        unawaited(getIt<PushService>().openLink(DeepLink.fromData(data)));
      } catch (e) {
        debugPrint('Unreadable notification payload: $e');
      }
    },
  );

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((message) {
    // Badge first: the user may never open the banner.
    getIt<PushService>().onForegroundMessage(message);

    if (message.notification != null) {
      if (!Platform.isAndroid) return; // iOS presents it itself.
      flutterLocalNotificationsPlugin.show(
        id: message.notification.hashCode,
        title: message.notification?.title,
        body: message.notification?.body,
        notificationDetails: _notificationDetails,
        payload: jsonEncode(message.data),
      );
      return;
    }
    _showDataNotification(message);
  });
}

class DigitalTradePortal extends StatelessWidget {
  const DigitalTradePortal({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: getIt<WorkspaceCubit>()),
        BlocProvider.value(value: getIt<SessionCubit>()),
        BlocProvider.value(value: getIt<NotificationsCubit>()),
      ],
      // The theme is per-workspace and server-driven: switching sides must
      // visibly recolour the app.
      child: BlocBuilder<WorkspaceCubit, WorkspaceState?>(
        buildWhen: (previous, current) => previous?.theme != current?.theme,
        builder: (context, workspace) {
          final tokens = workspace?.theme ?? ThemeTokens.fallbackFor(Workspace.trader);
          return MaterialApp.router(
            title: 'التكامل التجاري الرقمي',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(tokens, context.locale.languageCode),
            // The same tokens, inverted: a warehouse aisle and a truck cab
            // are where this app actually gets used.
            darkTheme: buildAppTheme(
              tokens,
              context.locale.languageCode,
              brightness: Brightness.dark,
            ),
            themeMode: ThemeMode.system,
            routerConfig: AppRouter.router,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
          );
        },
      ),
    );
  }
}
