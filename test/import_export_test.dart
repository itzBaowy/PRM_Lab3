import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fap_attendance/models/workspace.dart';
import 'package:fap_attendance/services/attendance_engine.dart';
import 'package:fap_attendance/services/file_service.dart';
import 'package:fap_attendance/services/markbook_parser.dart';

import 'support.dart';

void main() {
  final engine = AttendanceEngine(now: () => testDay);
  final parser = MarkbookParser(engine);
  final rows = [
    MarkbookParser.columns,
    ['SE1901', 'PRM393', 'SE000001', 'Nguyễn An', 'student@example.test'],
  ];
  List<ClassRoom> parse(Uint8List bytes, String name) => parser.parse(
    bytes,
    name,
    semester: 'Fall 2026',
    start: testDay,
    weeks: 2,
    rules: [ScheduleRule(testDay.weekday, 1)],
  );
  test('XLSX reads actual workbook bytes', () {
    final excel = Excel.createExcel();
    for (final row in rows) {
      excel['Sheet1'].appendRow(row.map(TextCellValue.new).toList());
    }
    final result = parse(Uint8List.fromList(excel.encode()!), 'markbook.xlsx');
    expect(result.single.students.single.name, 'Nguyễn An');
  });
  test('ODS reads actual zipped content xml', () {
    final xml =
        '<?xml version="1.0"?><office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"><office:body><office:spreadsheet><table:table>${rows.map((r) => '<table:table-row>${r.map((v) => '<table:table-cell><text:p>$v</text:p></table:table-cell>').join()}</table:table-row>').join()}</table:table></office:spreadsheet></office:body></office:document-content>';
    final bytes = utf8.encode(xml), zip = Archive();
    zip.addFile(ArchiveFile('content.xml', bytes.length, bytes));
    expect(
      parse(
        Uint8List.fromList(ZipEncoder().encode(zip)!),
        'markbook.ods',
      ).single.students.single.id,
      'SE000001',
    );
  });
  test('invalid workbook fails with actionable message', () {
    expect(
      () => parse(Uint8List.fromList([1, 2, 3]), 'bad.xlsx'),
      throwsA(isA<AppFailure>()),
    );
  });
  test('duplicate student rejected before mutation', () {
    expect(
      () => parser.parseRows(
        [...rows, rows.last],
        semester: 'Fall',
        start: testDay,
        weeks: 1,
        rules: [const ScheduleRule(1, 1)],
      ),
      throwsA(isA<AppFailure>()),
    );
  });
  test('JSON export matches closed roster and metadata', () {
    final c = fixture().classes.single,
        m = fixture().classes.single.meetings.first;
    m.state = MeetingState.active;
    engine.mark(c, m, 'SE000001', Mark.present);
    engine.close(c, m);
    final file = ExportService().generate(c, m, 'json');
    final j = jsonDecode(utf8.decode(file.bytes));
    expect(j['present'], 1);
    expect(j['absent'], 1);
    expect(j['students'].length, 2);
    expect(file.name, endsWith('.json'));
  });
  test('export rejects unfinished meeting', () {
    final c = fixture().classes.single;
    expect(
      () => ExportService().generate(c, c.meetings.first, 'csv'),
      throwsA(isA<AppFailure>()),
    );
  });
  test('CSV protects formula cells and escapes double quotes', () {
    final c = fixture().classes.single,
        m = fixture().classes.single.meetings.first;
    c.students[0] = Student(
      id: 'SE000001',
      name: '=HYPERLINK("x")',
      email: 'a@example.test',
    );
    m.state = MeetingState.active;
    engine.close(c, m);
    final text = utf8.decode(ExportService().generate(c, m, 'csv').bytes);
    expect(text, contains("'=HYPERLINK"));
    expect(text, contains('""x""'));
  });
}
