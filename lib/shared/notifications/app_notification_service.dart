import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../supabase/supabase_provider.dart';
import 'notification_destination.dart';

typedef NotificationTargetHandler = void Function(String target);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

class AppNotificationService {
  AppNotificationService._();

  static final AppNotificationService instance = AppNotificationService._();

  static const String _tokenTable = 'app_push_tokens';
  static const String _androidChannelId = 'mmgold_updates';
  static const String _androidChannelName = 'MMGold Updates';
  static const String _androidChannelDescription =
      'Gold price updates and admin announcements';

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  NotificationTargetHandler? _onTarget;
  bool _initialized = false;

  Future<String?> initialize({
    required NotificationTargetHandler onTarget,
  }) async {
    _onTarget = onTarget;
    if (_initialized) return null;
    _initialized = true;

    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _setupLocalNotifications();
    await _requestNotificationPermissions();
    await _configureFirebaseMessaging();

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage == null) return null;
    return _extractTarget(initialMessage.data);
  }

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundLocalNotificationTapped,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: _androidChannelDescription,
        importance: Importance.max,
      ),
    );
  }

  Future<void> _requestNotificationPermissions() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      carPlay: false,
      criticalAlert: false,
      announcement: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _local.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _configureFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    await _registerPushToken(await messaging.getToken());
    messaging.onTokenRefresh.listen((token) {
      _registerPushToken(token);
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _notifyTarget(_extractTarget(message.data));
    });
  }

  Future<void> _registerPushToken(String? token) async {
    final clean = (token ?? '').trim();
    if (clean.isEmpty) return;

    final payload = <String, dynamic>{
      'token': clean,
      'platform': _platformName(),
      'is_active': true,
      'last_seen_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      await SupabaseProvider.client
          .from(_tokenTable)
          .upsert(payload, onConflict: 'token');
    } catch (_) {}
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? _stringOf(message.data['title']);
    final body = notification?.body ?? _stringOf(message.data['body']);
    final target = _extractTarget(message.data);

    if (title.trim().isEmpty || body.trim().isEmpty) return;

    await _local.show(
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode({'target': target}),
    );
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    final target = _extractPayloadTarget(response.payload);
    _notifyTarget(target);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundLocalNotificationTapped(
      NotificationResponse response) {}

  void _notifyTarget(String? target) {
    _onTarget?.call(NotificationDestination.normalize(target));
  }

  String _extractTarget(Map<String, dynamic> data) {
    return NotificationDestination.normalize(data['target']?.toString());
  }

  String _extractPayloadTarget(String? payload) {
    if (payload == null || payload.isEmpty) {
      return NotificationDestination.defaultTarget;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        return NotificationDestination.normalize(decoded['target']?.toString());
      }
    } catch (_) {}
    return NotificationDestination.defaultTarget;
  }

  String _stringOf(dynamic raw) {
    if (raw == null) return '';
    return raw.toString();
  }
}
