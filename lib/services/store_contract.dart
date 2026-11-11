import '../models/workspace.dart';

abstract class WorkspaceStore {
  Future<Workspace?> load(String uid);
  Future<void> save(Workspace workspace);
  Future<void> clear(String uid);
}
