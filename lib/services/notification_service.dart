import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.classId,
    this.meetingId,
  });
  final String id, title, body;
  final String? classId, meetingId;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'classId': classId,
    'meetingId': meetingId,
  };
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'],
    title: j['title'],
    body: j['body'],
    classId: j['classId'],
    meetingId: j['meetingId'],
  );
}

Future<void> persistNotification(RemoteMessage message) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  final prefs = SharedPreferencesAsync();
  // One key per message avoids read-modify-write races between isolates.
  final item = AppNotification(
    id: message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
    title: message.notification?.title ?? message.data['title'] ?? 'Thông báo',
    body: message.notification?.body ?? message.data['body'] ?? '',
    classId: message.data['classId'],
    meetingId: message.data['meetingId'],
  );
  await prefs.setString('notice_${uid}_${item.id}', jsonEncode(item.toJson()));
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await persistNotification(message);
}

class NotificationService {
  NotificationService(this.messaging, this.db);
  final FirebaseMessaging messaging;
  final FirebaseFirestore db;
  final _opened = StreamController<AppNotification>.broadcast();
  final _received = StreamController<void>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Stream<AppNotification> get opened => _opened.stream;
  Stream<void> get received => _received.stream;
  AppNotification? pendingOpen;
  String? _uid, _token;
  Future<void> initialize(String uid) async {
    if (_uid == uid) return;
    await stop();
    _uid = uid;
    Future<void> receive(RemoteMessage message, bool open) async {
      await persistNotification(message);
      _received.add(null);
      if (open) {
        final item = AppNotification(
          id: message.messageId ?? '',
          title: message.notification?.title ?? 'Thông báo',
          body: message.notification?.body ?? '',
          classId: message.data['classId'],
          meetingId: message.data['meetingId'],
        );
        pendingOpen = item;
        _opened.add(item);
      }
    }

    _subscriptions.add(
      FirebaseMessaging.onMessage.listen((m) => unawaited(receive(m, false))),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => unawaited(receive(m, true)),
      ),
    );
    _subscriptions.add(
      messaging.onRegistered.listen(
        (token) => unawaited(_saveToken(uid, token)),
      ),
    );
    final initial = await messaging.getInitialMessage();
    if (initial != null) await receive(initial, true);
  }

  Future<String> requestPermission() async {
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return 'Bạn chưa cho phép thông báo. Có thể bật lại trong cài đặt Android.';
    }
    await messaging.register();
    return 'Đã bật thông báo trên thiết bị.';
  }

  Future<void> _saveToken(String uid, String token) async {
    _token = token;
    await db.collection('users').doc(uid).collection('devices').doc(token).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<AppNotification>> list(String uid) async {
    final prefs = SharedPreferencesAsync();
    final keys = (await prefs.getKeys()).where(
      (k) => k.startsWith('notice_${uid}_'),
    );
    final result = <AppNotification>[];
    for (final key in keys) {
      final value = await prefs.getString(key);
      if (value != null) {
        result.add(AppNotification.fromJson(jsonDecode(value)));
      }
    }
    return result.reversed.toList();
  }

  Future<void> clear(String uid) async {
    final prefs = SharedPreferencesAsync();
    for (final key in (await prefs.getKeys()).where(
      (k) => k.startsWith('notice_${uid}_'),
    )) {
      await prefs.remove(key);
    }
    if (_token != null) {
      try {
        await db
            .collection('users')
            .doc(uid)
            .collection('devices')
            .doc(_token)
            .delete()
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        /* Token invalidation below prevents later delivery. */
      }
    }
    try {
      await messaging.unregister().timeout(const Duration(seconds: 5));
    } catch (_) {
      /* Local data still must be cleared while offline. */
    }
    await stop();
  }

  Future<void> stop() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    _uid = null;
    _token = null;
    pendingOpen = null;
  }
}
