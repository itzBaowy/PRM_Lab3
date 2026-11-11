import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workspace.dart';
import 'file_service.dart';

class DriveService {
  DriveService(this.uid);
  final String uid;
  drive.DriveApi? _api;
  http.Client? _client;
  bool get connected => _api != null;
  Future<void> connect() async {
    await GoogleSignIn.instance.initialize();
    final account = await GoogleSignIn.instance.authenticate();
    final authorization = await account.authorizationClient.authorizeScopes([
      drive.DriveApi.driveFileScope,
    ]);
    _client?.close();
    _client = authorization.authClient(scopes: [drive.DriveApi.driveFileScope]);
    _api = drive.DriveApi(_client!);
  }

  Future<List<drive.File>> markbooks() async {
    if (_api == null) throw const AppFailure('Hãy kết nối Google Drive trước.');
    final files = await _api!.files.list(
      q: "trashed = false and (mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' or mimeType = 'application/vnd.oasis.opendocument.spreadsheet')",
      $fields: 'files(id,name,mimeType)',
      pageSize: 100,
    );
    return files.files ?? [];
  }

  Future<PickedMarkbook> download(String id, String name) async {
    final media = await _api!.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;
    final chunks = <int>[];
    await for (final chunk in media.stream) {
      chunks.addAll(chunk);
      if (chunks.length > 10 * 1024 * 1024) {
        throw const AppFailure('Tệp vượt quá 10 MB.');
      }
    }
    return PickedMarkbook(name, Uint8List.fromList(chunks));
  }

  Future<String> upload(GeneratedFile file) async {
    if (_api == null) throw const AppFailure('Hãy kết nối Google Drive trước.');
    final prefs = SharedPreferencesAsync();
    final key = 'drive_${uid}_${file.name}';
    final old = await prefs.getString(key);
    final hash = sha256.convert(file.bytes).toString();
    final media = drive.Media(
      Stream.value(file.bytes),
      file.bytes.length,
      contentType: file.mime,
    );
    final drive.File result;
    if (old != null) {
      final record = jsonDecode(old);
      final remote = await _api!.files.get(
        record['id'],
        $fields: 'id,version,webViewLink',
      ) as drive.File;
      if (remote.version != record['version']) {
        throw const AppFailure('conflict');
      }
      if (record['hash'] == hash) {
        return remote.webViewLink ??
            'https://drive.google.com/file/d/${remote.id}/view';
      }
      result = await _api!.files.update(
        drive.File()..name = file.name,
        record['id'],
        uploadMedia: media,
        $fields: 'id,version,webViewLink',
      );
    } else {
      result = await _api!.files.create(
        drive.File()
          ..name = file.name
          ..mimeType = file.mime,
        uploadMedia: media,
        $fields: 'id,version,webViewLink',
      );
    }
    await prefs.setString(
      key,
      jsonEncode({'id': result.id, 'version': result.version, 'hash': hash}),
    );
    return result.webViewLink ??
        'https://drive.google.com/file/d/${result.id}/view';
  }

  Future<void> clear() async {
    _client?.close();
    _api = null;
    _client = null;
    final prefs = SharedPreferencesAsync();
    for (final key in (await prefs.getKeys()).where(
      (k) => k.startsWith('drive_${uid}_'),
    )) {
      await prefs.remove(key);
    }
  }
}
