import 'package:firebase_remote_config/firebase_remote_config.dart';

class AppConfig {
  const AppConfig({this.linkEnabled = true, this.absenceWarningPercent = 20});
  final bool linkEnabled;
  final int absenceWarningPercent;
}

class ConfigService {
  ConfigService(this.remote);
  final FirebaseRemoteConfig remote;
  AppConfig current = const AppConfig();
  Future<AppConfig> refresh() async {
    await remote.setDefaults({
      'attendance_link_enabled': true,
      'absence_warning_percent': 20,
    });
    await remote.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 1),
      ),
    );
    await remote.fetchAndActivate();
    current = AppConfig(
      linkEnabled: remote.getBool('attendance_link_enabled'),
      absenceWarningPercent: remote
          .getInt('absence_warning_percent')
          .clamp(1, 100),
    );
    return current;
  }
}
