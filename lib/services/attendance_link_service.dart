import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/workspace.dart';

class LinkSession {
  const LinkSession(this.id, this.url, this.code);
  final String id, url;
  final String? code;
}

class AttendanceLinkService {
  AttendanceLinkService(this.db, this.auth, this.baseUrl);
  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final String baseUrl;
  DocumentReference<Map<String, dynamic>> session(String id) =>
      db.collection('attendanceSessions').doc(id);

  Future<LinkSession> create(ClassRoom c, Meeting m, bool withCode) async {
    if (m.state != MeetingState.active) {
      throw const AppFailure('Hãy bắt đầu buổi học trước khi tạo link.');
    }
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || !uri.hasAuthority || uri.scheme != 'https') {
      throw const AppFailure(
        'Chưa cấu hình địa chỉ trang điểm danh. Hãy cấu hình ATTENDANCE_BASE_URL.',
      );
    }
    final id = m.linkId ?? db.collection('attendanceSessions').doc().id;
    final ref = session(id);
    if (m.linkId != null) {
      final previous = await ref.get(const GetOptions(source: Source.server));
      if (previous.data()?['open'] == true) {
        final secret = await ref.collection('private').doc('code').get();
        return LinkSession(
          id,
          uri.replace(queryParameters: {'session': id}).toString(),
          secret.data()?['code'],
        );
      }
    }
    if (c.students.length > 450) {
      throw const AppFailure('Link hỗ trợ tối đa 450 sinh viên mỗi lớp.');
    }
    final code = withCode
        ? (100000 + Random.secure().nextInt(900000)).toString()
        : null;
    final batch = db.batch();
    batch.set(ref, {
      'ownerUid': auth.currentUser!.uid,
      'classCode': c.code,
      'subject': c.subject,
      'meetingId': m.id,
      'date': dayKey(m.date),
      'slot': m.number,
      'timeSlot': m.timeSlot,
      'open': true,
      'codeEnabled': withCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(ref.collection('private').doc('code'), {'code': code ?? ''});
    for (final student in c.students) {
      batch.set(ref.collection('members').doc(student.email), {
        'studentId': student.id,
        'name': student.name,
      });
    }
    await batch.commit().timeout(const Duration(seconds: 20));
    return LinkSession(
      id,
      uri.replace(queryParameters: {'session': id}).toString(),
      code,
    );
  }

  Future<List<String>> submissions(String id) async {
    final snapshot = await session(id)
        .collection('submissions')
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.map((d) => d.data()['studentId'] as String).toList();
  }

  Future<void> stop(String id) async {
    await session(id)
        .update({'open': false, 'updatedAt': FieldValue.serverTimestamp()})
        .timeout(const Duration(seconds: 15));
  }

  Future<Map<String, dynamic>> beginStudentVisit(String id) async {
    final user = auth.currentUser;
    if (user == null || user.email == null || !user.emailVerified) {
      throw const AppFailure(
        'Hãy đăng nhập Google bằng email thuộc danh sách lớp.',
      );
    }
    final info = await session(id).get(const GetOptions(source: Source.server));
    if (info.data()?['open'] != true) {
      throw const AppFailure(
        'Buổi học đã dừng nhận. Link không còn nhận điểm danh.',
      );
    }
    final member = await session(id)
        .collection('members')
        .doc(user.email!.toLowerCase())
        .get();
    if (!member.exists) {
      throw const AppFailure('Email không thuộc danh sách lớp.');
    }
    await session(id)
        .collection('visits')
        .doc(user.uid)
        .set({'startedAt': FieldValue.serverTimestamp()});
    return {...info.data()!, ...member.data()!};
  }

  Future<void> submitStudent(String id, String code) async {
    final user = auth.currentUser!;
    final ref = session(id)
        .collection('submissions')
        .doc(user.email!.toLowerCase());
    final existing = await ref.get(const GetOptions(source: Source.server));
    if (existing.exists) return;
    final member = await session(id)
        .collection('members')
        .doc(user.email!.toLowerCase())
        .get();
    await ref.set({
      'studentId': member.data()!['studentId'],
      'uid': user.uid,
      'code': code,
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }
}
