import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_cubit.dart';
import 'package:digital_trade_portal/core/shared_cubits/change_language/change_language_states.dart';
import 'package:digital_trade_portal/core/utils/services/local_services/cache_keys.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:digital_trade_portal/features/auth/presentation/view_models/auth/auth_cubit.dart';
import 'package:digital_trade_portal/features/main_layout/presenation/view_model/change_nav_bar_status/change_nav_bar_status_cubit.dart';
import 'package:digital_trade_portal/firebase_options.dart';
import 'core/utils/roots/app_router.dart';
import 'core/utils/services/local_services/cache_helper.dart';
import 'core/utils/services/remote_services/service_locator.dart';
import 'core/utils/theme/app_theme.dart';

// Local Notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Background handler for FCM
@pragma('vm:entry-point')
Future _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // On iOS, background messages with a notification payload are handled
  // automatically by the system — no need to show a local notification.
  // Only show local notifications for data-only messages.
  if (message.notification == null) {
    final title = message.data['title'];
    final body = message.data['body'];
    if (title != null && body != null) {
      flutterLocalNotificationsPlugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'dtp_channel_id',
            'DigitalTradePortal',
            channelDescription: 'dtp_channel_description',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'notification_icon',
            colorized: true,
            color: Color(0xff03745f),
          ),
          // ✅ إضافة إعدادات iOS للإشعارات المحلية
          iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
      );
    }
  }
}

// Show a local notification for messages with a notification section
void _showLocalNotification(RemoteMessage message) {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'dtp_channel_id',
    'DigitalTradePortal',
    channelDescription: 'dtp_channel_description',
    importance: Importance.max,
    priority: Priority.high,
    icon: 'notification_icon',
    colorized: true,
    color: Color(0xff03745f),
  );

  // ✅ إضافة إعدادات iOS للإشعارات المحلية
  const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

  flutterLocalNotificationsPlugin.show(
    id: message.notification?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: message.notification?.title,
    body: message.notification?.body,
    notificationDetails: platformDetails,
  );
}

Future<void> _safeSubscribeToTopic(String topic) async {
  try {
    // ✅ على iOS لازم نستنى الـ APNs token الأول قبل ما نجيب FCM token
    if (Platform.isIOS) {
      String? apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('Waiting for APNs token...');
        // ننتظر شوية ونحاول تاني
        await Future.delayed(const Duration(seconds: 3));
        apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          debugPrint('APNs token still null — cannot get FCM token on iOS');
          return;
        }
      }
      debugPrint('APNs Token: $apnsToken');
    }

    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await CacheHelper.saveData(key: "deviceToken", value: token);
      debugPrint("Device Token: $token");
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('Successfully subscribed to topic: $topic');
    } else {
      debugPrint('Failed to get device token, cannot subscribe to topic');
    }
  } catch (e) {
    debugPrint('Error subscribing to topic $topic: $e');
  }
}

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  await CacheHelper.init();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ✅ تسجيل background handler قبل أي حاجة تانية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize local notifications
  const AndroidInitializationSettings androidInitSettings = AndroidInitializationSettings('notification_icon');
  const DarwinInitializationSettings iosInitSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const InitializationSettings initSettings = InitializationSettings(
    android: androidInitSettings,
    iOS: iosInitSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('Tapped notification payload: ${response.payload}');
    },
  );

  // ✅ طلب صلاحيات iOS للإشعارات المحلية مع await
  if (Platform.isIOS) {
    final bool? granted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    debugPrint('iOS local notification permissions granted: $granted');
  }

  // ✅ طلب صلاحيات Firebase Messaging مع await
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  debugPrint('Firebase Messaging permission status: ${settings.authorizationStatus}');

  // ✅ ضبط عرض الإشعارات في الـ foreground مع await
  await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

  // Handlers
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('onMessage received: ${message.messageId}');
    // ✅ على iOS لما التطبيق في الـ foreground:
    // setForegroundNotificationPresentationOptions بيتكفل بالعرض
    // للـ messages اللي فيها notification payload.
    // بس لو عايز تتحكم أكتر، ممكن تعرض local notification:
    if (message.notification != null) {
      // على Android بنعرض local notification عشان مفيش
      // setForegroundNotificationPresentationOptions
      if (Platform.isAndroid) {
        _showLocalNotification(message);
      }
      // على iOS الـ system بيعرض الإشعار تلقائياً بسبب
      // setForegroundNotificationPresentationOptions
      // لو عايز تعرضه manual برضو على iOS، شيل الـ if condition
    }

    // ✅ لو data-only message، اعرضها على كل الأنظمة
    if (message.notification == null) {
      final title = message.data['title'];
      final body = message.data['body'];
      if (title != null && body != null) {
        flutterLocalNotificationsPlugin.show(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'dtp_channel_id',
              'DigitalTradePortal',
              channelDescription: 'dtp_channel_description',
              importance: Importance.max,
              priority: Priority.high,
              icon: 'notification_icon',
              colorized: true,
              color: Color(0xff03745f),
            ),
            iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
          ),
        );
      }
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('onMessageOpenedApp data: ${message.data}');
  });

  // ✅ التعامل مع الإشعار اللي فتح التطبيق وهو مغلق
  RemoteMessage? initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    debugPrint('App opened from terminated state with data: ${initialMessage.data}');
    // هنا ممكن تعمل navigation بناءً على الـ data
  }

  _safeSubscribeToTopic('all');

  if (CacheKeysManger.getUserLanguage().isEmpty) {
    await CacheHelper.saveData(key: 'lang', value: 'ar');
  }

  setup();
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale("ar"), Locale("en")],
      saveLocale: true,
      startLocale: Locale("ar"),
      path: "lib/core/language",
      child: const DigitalTradePortal(),
    ),
  );
}

class DigitalTradePortal extends StatelessWidget {
  const DigitalTradePortal({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => AuthCubit()),
        BlocProvider(create: (context) => ChangeLanguageCubit()),
        BlocProvider(create: (context) => ChangeNavBarStatusCubit()),
      ],
      child: BlocBuilder<ChangeLanguageCubit, ChangeLanguageStates>(
        builder: (context, langState) {
          return MaterialApp.router(
            title: "Tajer Id",
            theme: themeDataLight,
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
                child: child!,
              );
            },
            debugShowCheckedModeBanner: false,
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
