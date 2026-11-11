import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/workspace.dart';
import 'store_contract.dart';

class LocalWorkspaceStore implements WorkspaceStore {
  final _preferences = SharedPreferencesAsync();
  @override
  Future<Workspace?> load(String uid) async {
    final value = await _preferences.getString('workspace_$uid');
    return value == null ? null : Workspace.fromJson(jsonDecode(value));
  }

  @override
  Future<void> save(Workspace workspace) => _preferences.setString(
    'workspace_${workspace.ownerUid}',
    jsonEncode(workspace.toJson()),
  );
  @override
  Future<void> clear(String uid) => _preferences.remove('workspace_$uid');
}
