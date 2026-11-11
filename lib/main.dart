
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/telemetry_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
    if (apiKey.isNotEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: apiKey,
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
          storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
          authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
    final telemetry = FirebaseTelemetryService(
      FirebaseAnalytics.instance,
      kIsWeb ? null : FirebaseCrashlytics.instance,
    );
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
    runApp(AttendanceApp(telemetry: telemetry));
  } catch (_) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: AppPage(
          title: 'FAP Attendance',
          child: PageList(
            children: [
              const Icon(
                Icons.school_outlined,
                size: AppSpace.touch * 2,
                color: AppColors.primary,
              ),
              const SectionTitle('Cần kết nối Firebase'),
              const Text(
                'Ứng dụng chưa có cấu hình Firebase hợp lệ. Vui lòng hoàn tất thiết lập để đăng nhập và sử dụng dữ liệu của bạn.',
              ),
              const Text(
                'Hướng dẫn dành cho nhóm phát triển nằm trong README.md và docs/firebase-setup.md.',
              ),
              AppButton('Thử kết nối lại', onPressed: main),
            ],
          ),
        ),
      ),
    );
  }
}
