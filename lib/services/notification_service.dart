import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_keys.dart';
import '../firebase_options.dart';
import '../pages/kos_detail_page.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  debugPrint('[BACKGROUND] ${message.notification?.title}');
  debugPrint('[BACKGROUND] ${message.notification?.body}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? currentToken;

  /// Meminta izin notifikasi (Praktik 8)
  Future<AuthorizationStatus> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('Notification permission: ${settings.authorizationStatus.name}');
      return settings.authorizationStatus;
    } catch (e) {
      debugPrint('Error requestPermission: $e');
      return AuthorizationStatus.notDetermined;
    }
  }

  /// Mendapatkan FCM Token perangkat (Praktik 9)
  Future<String?> getToken() async {
    try {
      // ignore: deprecated_member_use
      currentToken = await _messaging.getToken();
      debugPrint('FCM Token: $currentToken');
      return currentToken;
    } catch (e) {
      debugPrint('Error getting token: $e');
      return null;
    }
  }

  /// Simpan token ke database Supabase untuk device registration
  Future<void> saveTokenToSupabase(String token) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('device_tokens').upsert({
        'token': token,
        'user_id': user.id,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugPrint('Token tersimpan di Supabase');
    } catch (e) {
      debugPrint('Gagal menyimpan token ke Supabase: $e');
    }
  }

  /// Inisialisasi listener notifikasi Foreground & Background (Praktik 10)
  Future<void> init() async {
    await requestPermission();
    final token = await getToken();
    if (token != null) {
      await saveTokenToSupabase(token);
    }

    // ignore: deprecated_member_use
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token diperbarui');
      currentToken = newToken;
      saveTokenToSupabase(newToken);
    });

    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {}

    // FOREGROUND: saat aplikasi sedang terbuka
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FOREGROUND] Notification received');
      debugPrint('title: ${message.notification?.title}');
      debugPrint('body : ${message.notification?.body}');
      debugPrint('data : ${message.data}');

      final title = message.notification?.title ?? 'KosFinder Notifikasi';
      final body = message.notification?.body ?? 'Ada pesan baru.';

      messengerKey.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text('$title\n$body'),
          action: SnackBarAction(
            label: 'LIHAT',
            onPressed: () {
              final kosId = message.data['kos_id'];
              if (kosId != null) {
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (_) => KosDetailPage(kosId: kosId.toString()),
                  ),
                );
              }
            },
          ),
        ),
      );
    });
  }

  /// Interaksi saat notifikasi ditekan (Bonus Praktik)
  Future<void> setupInteractedMessage() async {
    // 1. Kondisi TERMINATED (aplikasi mati lalu dibuka dari notifikasi)
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);

    // 2. Kondisi BACKGROUND (aplikasi di latar belakang lalu dibuka dari notifikasi)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
  }

  void _handleTap(RemoteMessage message) {
    final kosId = message.data['kos_id'];
    if (kosId == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => KosDetailPage(kosId: kosId.toString()),
      ),
    );
  }
}
