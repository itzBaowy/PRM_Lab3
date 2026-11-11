import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/workspace.dart';
import 'store_contract.dart';

class LocalWorkspaceStore implements WorkspaceStore {
  Future<Directory> folder(String uid) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(
      '${root.path}/workspaces/${Uri.encodeComponent(uid)}',
    );
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Workspace?> load(String uid) async {
    final dir = await folder(uid);
    final file = File('${dir.path}/workspace.json');
    final backup = File('${dir.path}/workspace.backup.json');
    if (!await file.exists()) {
      if (!await backup.exists()) return null;
      await backup.copy(file.path);
    }
    try {
      return Workspace.fromJson(jsonDecode(await file.readAsString()));
    } catch (_) {
      throw const AppFailure(
        'Không đọc được dữ liệu trên máy. Bản gốc vẫn được giữ lại.',
      );
    }
  }

  @override
  Future<void> save(Workspace workspace) async {
    final dir = await folder(workspace.ownerUid);
    final file = File('${dir.path}/workspace.json');
    final next = File('${dir.path}/workspace.next.json');
    await next.writeAsString(jsonEncode(workspace.toJson()), flush: true);
    final backup = File('${dir.path}/workspace.backup.json');
    if (await file.exists()) await file.copy(backup.path);
    await next.rename(file.path);
  }

  @override
  Future<void> clear(String uid) async {
    final dir = await folder(uid);
    await dir.delete(recursive: true);
  }
}
