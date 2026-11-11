import 'dart:async';

import 'package:firebase_storage/firebase_storage.dart';

import 'file_service.dart';

class CloudFileService {
  CloudFileService(this.storage);
  final FirebaseStorage storage;
  Future<String> upload(
    String uid,
    GeneratedFile file,
    void Function(double) onProgress,
  ) async {
    final ref = storage.ref('reports/$uid/${file.name}');
    final task = ref.putData(
      file.bytes,
      SettableMetadata(contentType: file.mime),
    );
    final subscription = task.snapshotEvents.listen((snapshot) {
      onProgress(
        snapshot.totalBytes == 0
            ? 0
            : snapshot.bytesTransferred / snapshot.totalBytes,
      );
    });
    try {
      await task;
      return await ref.getDownloadURL();
    } finally {
      await subscription.cancel();
    }
  }
}
