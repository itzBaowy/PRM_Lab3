import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/workspace.dart';

abstract class CloudWorkspaceService {
  Future<Workspace?> fetch(String uid);
  Future<int> push(Workspace workspace);
}

class FirestoreWorkspaceService implements CloudWorkspaceService {
  FirestoreWorkspaceService(this.db);
  final FirebaseFirestore db;
  DocumentReference<Map<String, dynamic>> ref(String uid) =>
      db.collection('workspaces').doc(uid);
  @override
  Future<Workspace?> fetch(String uid) async {
    final snapshot = await ref(uid)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final workspace = Workspace.fromJson(
      Map<String, dynamic>.from(snapshot.data()!['payload']),
    );
    workspace.cloudRevision = snapshot.data()!['revision'];
    workspace.syncState = SyncState.synced;
    return workspace;
  }

  @override
  Future<int> push(Workspace workspace) async {
    if (utf8.encode(jsonEncode(workspace.toJson())).length > 800000) {
      throw const AppFailure(
        'Workspace vượt giới hạn đồng bộ 800 KB. Hãy xuất bản sao và tách học kỳ.',
      );
    }
    return db.runTransaction((tx) async {
      final snapshot = await tx.get(ref(workspace.ownerUid));
      final current = (snapshot.data()?['revision'] as int?) ?? 0;
      if (current != workspace.cloudRevision) {
        throw const AppFailure('conflict');
      }
      final next = current + 1;
      tx.set(ref(workspace.ownerUid), {
        'ownerUid': workspace.ownerUid,
        'revision': next,
        'payload': workspace.toJson(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return next;
    });
  }
}
