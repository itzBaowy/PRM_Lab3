import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:xml/xml.dart';
import '../models/workspace.dart';
import 'attendance_engine.dart';

class MarkbookParser {
  MarkbookParser(this.engine);
  final AttendanceEngine engine;
  static const columns = ['class_code', 'subject', 'student_id', 'student_name', 'email'];

  List<ClassRoom> parse(Uint8List bytes, String filename, {required String semester, required DateTime start, required int weeks, required List<ScheduleRule> rules}) {
    if (semester.trim().isEmpty) throw const AppFailure('Vui lòng nhập học kỳ.');
    if (bytes.length > 10 * 1024 * 1024) throw const AppFailure('Tệp quá lớn. Vui lòng chọn tệp dưới 10 MB.');
    List<List<String>> rows;
    try {
      if (filename.toLowerCase().endsWith('.xlsx')) {
        final workbook = Excel.decodeBytes(bytes);
        rows = workbook.tables.values.expand((t) => t.rows.map((r) => r.map((c) => c?.value?.toString().trim() ?? '').toList())).toList();
      } else if (filename.toLowerCase().endsWith('.ods')) {
        final zip = ZipDecoder().decodeBytes(bytes);
        final file = zip.findFile('content.xml');
        if (file == null || file.size > 20 * 1024 * 1024) throw const FormatException('Invalid ODS');
        final xml = XmlDocument.parse(utf8.decode(file.content as List<int>));
        rows = [];
        for (final row in xml.descendants.whereType<XmlElement>().where((e) => e.name.local == 'table-row')) {
          final cells = <String>[];
          for (final cell in row.childElements.where((e) => e.name.local == 'table-cell' || e.name.local == 'covered-table-cell')) {
            final count = int.tryParse(cell.getAttribute('number-columns-repeated', namespace: 'urn:oasis:names:tc:opendocument:xmlns:table:1.0') ?? '') ?? 1;
            final text = cell.descendants.whereType<XmlElement>().where((e) => e.name.local == 'p').map((e) => e.innerText).join(' ').trim();
            // Spreadsheet writers repeat trailing empty cells up to a million columns.
            if (text.isEmpty && cells.length >= columns.length) break;
            if (count > 100) throw const FormatException('Too many repeated columns');
            cells.addAll(List.filled(count, text));
          }
          if (cells.any((v) => v.isNotEmpty)) rows.add(cells);
          if (rows.length > 5000) throw const FormatException('Too many rows');
        }
      } else { throw const AppFailure('Chỉ hỗ trợ ODS hoặc XLSX.'); }
    } on AppFailure { rethrow; } catch (_) { throw const AppFailure('Không đọc được markbook. Kiểm tra định dạng và thử lại.'); }
    return parseRows(rows, semester: semester, start: start, weeks: weeks, rules: rules);
  }

  List<ClassRoom> parseRows(List<List<String>> rows, {required String semester, required DateTime start, required int weeks, required List<ScheduleRule> rules}) {
    if (rows.length > 5000) throw const AppFailure('Markbook vượt quá 5000 dòng.');
    final classes = <String, ClassRoom>{};
    List<String>? header;
    for (var n = 0; n < rows.length; n++) {
      final row = rows[n];
      if (row.every((v) => v.trim().isEmpty)) continue;
      final normalized = row.map((v) => v.trim().toLowerCase()).toList();
      if (columns.every(normalized.contains)) { header = normalized; continue; }
      if (header == null) throw AppFailure('Thiếu header: ${columns.join(', ')}. Xem mẫu markbook.');
      String read(String key) { final i = header!.indexOf(key); return i < row.length ? row[i].trim() : ''; }
      final code = read('class_code'), subject = read('subject'), id = read('student_id'), name = read('student_name'), email = read('email').toLowerCase();
      if ([code, subject, id, name].any((s) => s.isEmpty) || !RegExp(r'^[^\s/@]+@[^\s/@]+\.[^\s/@]+$').hasMatch(email)) throw AppFailure('Dòng ${n + 1}: thiếu thông tin hoặc email không hợp lệ.');
      final classId = engine.idFor('${semester.trim()}|$code|$subject');
      final c = classes.putIfAbsent(classId, () => ClassRoom(id: classId, code: code, subject: subject, semester: semester.trim(), students: [], meetings: engine.schedule(classId: classId, start: start, weeks: weeks, rules: rules)));
      if (c.students.any((s) => s.id == id || s.email == email)) throw AppFailure('Dòng ${n + 1}: trùng MSSV hoặc email trong lớp $code.');
      c.students.add(Student(id: id, name: name, email: email));
    }
    if (classes.isEmpty) throw const AppFailure('Markbook không có sinh viên.');
    return classes.values.toList();
  }
}
