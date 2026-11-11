import '../models/workspace.dart';
import '../services/drive_service.dart';
import '../services/notification_service.dart';
import 'auth_vm.dart';
import 'workspace_vm.dart';

class SessionVm {
  SessionVm(this.auth, this.workspace, this.notifications, this.drive);
  final AuthVm auth;
  final WorkspaceVm workspace;
  final NotificationService notifications;
  final DriveService drive;
  Future<bool> signOut() => auth.signOut(() async {
    if (!workspace.canSignOut)
      throw const AppFailure(
        'Hãy dừng các link đang nhận trước khi đăng xuất.',
      );
    await notifications.clear(workspace.uid);
    await drive.clear();
    await workspace.clear();
  });
}
