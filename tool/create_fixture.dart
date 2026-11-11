import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  final workbook = Excel.createExcel();
  final rows = [
    ['class_code','subject','student_id','student_name','email'],
    ['SE1901','PRM393','SE000001','Nguyễn Minh Anh','student1@example.test'],
    ['SE1901','PRM393','SE000002','Trần Gia Bảo','student2@example.test'],
  ];
  for (final row in rows) { workbook['Sheet1'].appendRow(row.map(TextCellValue.new).toList()); }
  Directory('test/fixtures').createSync(recursive: true);
  File('test/fixtures/lab3-fixture.xlsx').writeAsBytesSync(workbook.encode()!);
  File('test/fixtures/invalid.xlsx').writeAsStringSync('Intentionally invalid test fixture, not an XLSX workbook.');
  stdout.writeln('Created synthetic markbook fixtures in test/fixtures.');
}
