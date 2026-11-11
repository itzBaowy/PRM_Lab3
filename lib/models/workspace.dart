import 'dart:convert';

enum LoadState { loading, empty, error, data }

enum MeetingState { upcoming, active, closed }

enum SyncState { localOnly, pendingSync, synced, conflict }

enum Mark { present, absent }

String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
const timeSlots = ['07:00–09:15', '09:30–11:45', '12:30–14:45', '15:00–17:15'];

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class Student {
  Student({required this.id, required this.name, required this.email});
  final String id, name, email;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email};
  factory Student.fromJson(Map<String, dynamic> j) =>
      Student(id: j['id'], name: j['name'], email: j['email']);
}

class AuditEntry {
  AuditEntry({
    required this.before,
    required this.after,
    required this.reason,
    required this.at,
  });
  final Mark? before;
  final Mark after;
  final String reason;
  final DateTime at;
  Map<String, dynamic> toJson() => {
    'before': before?.name,
    'after': after.name,
    'reason': reason,
    'at': at.toIso8601String(),
  };
  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    before: j['before'] == null ? null : Mark.values.byName(j['before']),
    after: Mark.values.byName(j['after']),
    reason: j['reason'],
    at: DateTime.parse(j['at']),
  );
}

class AttendanceRecord {
  AttendanceRecord({
    required this.mark,
    required this.source,
    List<AuditEntry>? audit,
  }) : audit = audit ?? [];
  Mark mark;
  String source;
  final List<AuditEntry> audit;
  Map<String, dynamic> toJson() => {
    'mark': mark.name,
    'source': source,
    'audit': audit.map((a) => a.toJson()).toList(),
  };
  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    mark: Mark.values.byName(j['mark']),
    source: j['source'],
    audit: (j['audit'] as List)
        .map((a) => AuditEntry.fromJson(Map<String, dynamic>.from(a)))
        .toList(),
  );
}

class Meeting {
  Meeting({
    required this.id,
    required this.date,
    required this.timeSlot,
    required this.number,
    this.state = MeetingState.upcoming,
    Map<String, AttendanceRecord>? records,
    this.linkId,
    this.linkOpen = false,
  }) : records = records ?? {};
  final String id;
  DateTime date;
  int timeSlot, number;
  MeetingState state;
  final Map<String, AttendanceRecord> records;
  String? linkId;
  bool linkOpen;
  int get present => records.values.where((r) => r.mark == Mark.present).length;
  int get absent => records.values.where((r) => r.mark == Mark.absent).length;
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': dayKey(date),
    'timeSlot': timeSlot,
    'number': number,
    'state': state.name,
    'records': records.map((k, v) => MapEntry(k, v.toJson())),
    'linkId': linkId,
    'linkOpen': linkOpen,
  };
  factory Meeting.fromJson(Map<String, dynamic> j) => Meeting(
    id: j['id'],
    date: DateTime.parse(j['date']),
    timeSlot: j['timeSlot'],
    number: j['number'],
    state: MeetingState.values.byName(j['state']),
    records: (j['records'] as Map<String, dynamic>).map(
      (k, v) =>
          MapEntry(k, AttendanceRecord.fromJson(Map<String, dynamic>.from(v))),
    ),
    linkId: j['linkId'],
    linkOpen: j['linkOpen'] ?? false,
  );
}

class ClassRoom {
  ClassRoom({
    required this.id,
    required this.code,
    required this.subject,
    required this.semester,
    required this.students,
    required this.meetings,
    this.archived = false,
  });
  final String id, code, subject, semester;
  final List<Student> students;
  List<Meeting> meetings;
  bool archived;
  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'subject': subject,
    'semester': semester,
    'students': students.map((s) => s.toJson()).toList(),
    'meetings': meetings.map((m) => m.toJson()).toList(),
    'archived': archived,
  };
  factory ClassRoom.fromJson(Map<String, dynamic> j) => ClassRoom(
    id: j['id'],
    code: j['code'],
    subject: j['subject'],
    semester: j['semester'],
    students: (j['students'] as List)
        .map((s) => Student.fromJson(Map<String, dynamic>.from(s)))
        .toList(),
    meetings: (j['meetings'] as List)
        .map((m) => Meeting.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
    archived: j['archived'] ?? false,
  );
}

class Workspace {
  Workspace({
    required this.ownerUid,
    this.email = '',
    List<ClassRoom>? classes,
    this.revision = 0,
    this.cloudRevision = 0,
    this.syncState = SyncState.localOnly,
  }) : classes = classes ?? [];
  final String ownerUid;
  String email;
  List<ClassRoom> classes;
  int revision, cloudRevision;
  SyncState syncState;
  List<ClassRoom> get visibleClasses =>
      classes.where((c) => !c.archived).toList();
  ClassRoom classroom(String id) => classes.firstWhere((c) => c.id == id);
  Meeting meeting(String classId, String meetingId) =>
      classroom(classId).meetings.firstWhere((m) => m.id == meetingId);
  Workspace copy() => Workspace.fromJson(jsonDecode(jsonEncode(toJson())));
  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'ownerUid': ownerUid,
    'email': email,
    'classes': classes.map((c) => c.toJson()).toList(),
    'revision': revision,
    'cloudRevision': cloudRevision,
    'syncState': syncState.name,
  };
  factory Workspace.fromJson(Map<String, dynamic> j) => Workspace(
    ownerUid: j['ownerUid'],
    email: j['email'] ?? '',
    classes: (j['classes'] as List)
        .map((c) => ClassRoom.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
    revision: j['revision'] ?? 0,
    cloudRevision: j['cloudRevision'] ?? 0,
    syncState: SyncState.values.byName(j['syncState'] ?? 'localOnly'),
  );
}

class ScheduleRule {
  const ScheduleRule(this.weekday, this.timeSlot);
  final int weekday, timeSlot;
}
