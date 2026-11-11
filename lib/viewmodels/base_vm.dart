import 'package:flutter/foundation.dart';

import '../models/workspace.dart';
import '../services/telemetry_service.dart';

class BaseVm extends ChangeNotifier {
  BaseVm(this.telemetry);
  final TelemetryService telemetry;
  LoadState state = LoadState.empty;
  bool busy = false;
  String? error, message;
  bool _disposed = false;
  void changed() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> perform(
    String operation,
    Future<void> Function() action, {
    bool loading = false,
  }) async {
    if (busy) return false;
    busy = true;
    error = null;
    message = null;
    if (loading) state = LoadState.loading;
    changed();
    try {
      await action();
      if (state == LoadState.loading || state == LoadState.error) {
        state = LoadState.data;
      }
      return true;
    } catch (e, stack) {
      error = e is AppFailure
          ? (e.message == 'conflict'
                ? 'Có xung đột với bản trên đám mây. Dữ liệu trên máy được giữ nguyên để kiểm tra.'
                : e.message)
          : 'Không hoàn tất được thao tác. Kiểm tra kết nối hoặc quyền truy cập rồi thử lại.';
      if (loading) state = LoadState.error;
      await telemetry.error(e, stack, operation);
      return false;
    } finally {
      busy = false;
      changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
