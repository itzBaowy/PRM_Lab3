import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../models/workspace.dart';

class PickedMarkbook {
  const PickedMarkbook(this.name, this.bytes);
  final String name;
  final Uint8List bytes;
}

class GeneratedFile {
  const GeneratedFile(this.name, this.bytes, this.mime);
  final String name, mime;
  final Uint8List bytes;
}

class FileService {
  Future<PickedMarkbook?> pickMarkbook() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'ods'],
    );
    if (file == null) return null;
    if ((await file.length() ?? 0) > 10 * 1024 * 1024) {
      throw const AppFailure('Tệp vượt quá 10 MB.');
    }
    return PickedMarkbook(file.name, await file.readAsBytes());
  }

  Future<String?> save(GeneratedFile file) async => (await FilePicker.saveFile(
    fileName: file.name,
    bytes: file.bytes,
  ))?.toString();
  Future<void> share(GeneratedFile file) async => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(file.bytes, mimeType: file.mime)],
      fileNameOverrides: [file.name],
    ),
  );
  Future<void> shareLink(String link) async =>
      SharePlus.instance.share(ShareParams(text: link));
  Future<void> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}

class ExportService {
  GeneratedFile generate(ClassRoom c, Meeting m, String format) {
    if (m.state != MeetingState.closed ||
        c.students.any((s) => !m.records.containsKey(s.id))) {
      throw const AppFailure('Chỉ xuất buổi đã chốt đủ Present/Absent.');
    }
    if (!['json', 'csv'].contains(format)) {
      throw const AppFailure('Định dạng xuất không hợp lệ.');
    }
    final filename = '${c.code}_${c.subject}_${dayKey(m.date)}_slot${m.number}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final rows = c.students
        .map(
          (s) => {
            'student_id': s.id,
            'student_name': s.name,
            'email': s.email,
            'status': m.records[s.id]!.mark == Mark.present ? 'P' : 'A',
          },
        )
        .toList();
    final String content;
    if (format == 'json') {
      content = const JsonEncoder.withIndent('  ').convert({
        'schema_version': 1,
        'class_code': c.code,
        'subject': c.subject,
        'semester': c.semester,
        'meeting_id': m.id,
        'date': dayKey(m.date),
        'slot': m.number,
        'time_slot': m.timeSlot,
        'present': m.present,
        'absent': m.absent,
        'students': rows,
      });
    } else {
      String escape(Object? value) {
        var text = value.toString();
        if (RegExp(r'^[=+@\-\t\r]').hasMatch(text)) text = "'$text";
        return '"${text.replaceAll('"', '""')}"';
      }

      content =
          '\uFEFF${[
            ['class_code', 'subject', 'date', 'slot', 'student_id', 'student_name', 'email', 'status'],
            ...rows.map((r) => [c.code, c.subject, dayKey(m.date), m.number, ...r.values]),
          ].map((row) => row.map(escape).join(',')).join('\r\n')}';
    }
    return GeneratedFile(
      '$filename.$format',
      Uint8List.fromList(utf8.encode(content)),
      format == 'json' ? 'application/json' : 'text/csv',
    );
  }
}
