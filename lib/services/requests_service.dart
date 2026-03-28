import 'package:cloud_firestore/cloud_firestore.dart';

class RequestsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── إنشاء طلب إجازة ───
  Future<Map<String, dynamic>> createLeaveRequest({
    required String uid,
    required String empId,
    required String name,
    required String leaveType, // سنوية، مرضية، طارئة، بدون راتب
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final days = endDate.difference(startDate).inDays + 1;
    final now = DateTime.now();

    final data = {
      'uid': uid,
      'empId': empId,
      'name': name,
      'requestType': 'إجازة',
      'leaveType': leaveType,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'days': days,
      'reason': reason,
      'status': 'تحت الإجراء', // تحت الإجراء، تم الموافقة، مرفوض
      'createdAt': FieldValue.serverTimestamp(),
      'dateKey': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    };

    final doc = await _db.collection('requests').add(data);
    return {'success': true, 'id': doc.id, 'days': days};
  }

  // ─── إنشاء طلب إذن (انصراف مبكر أو تأخير) ───
  Future<Map<String, dynamic>> createPermissionRequest({
    required String uid,
    required String empId,
    required String name,
    required String permType, // انصراف مبكر، تأخير عن الحضور
    required String fromTime,
    required String toTime,
    required DateTime date,
    required String reason,
    int? fromMinutes, // total minutes from midnight
    int? toMinutes,   // total minutes from midnight
  }) async {
    final now = DateTime.now();

    // Calculate duration in hours
    double hours = 0;
    if (fromMinutes != null && toMinutes != null && toMinutes > fromMinutes) {
      hours = (toMinutes - fromMinutes) / 60.0;
    }

    final data = {
      'uid': uid,
      'empId': empId,
      'name': name,
      'requestType': 'إذن',
      'permType': permType,
      'fromTime': fromTime,
      'toTime': toTime,
      'date': Timestamp.fromDate(date),
      'reason': reason,
      'hours': hours,
      'status': 'تحت الإجراء',
      'createdAt': FieldValue.serverTimestamp(),
      'dateKey': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    };

    final doc = await _db.collection('requests').add(data);
    return {'success': true, 'id': doc.id, 'hours': hours};
  }

  // ─── جلب طلبات الموظف ───
  Stream<QuerySnapshot> getMyRequests(String uid) {
    return _db
        .collection('requests')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  // ─── جلب كل الطلبات المعلقة (للأدمن) ───
  Stream<QuerySnapshot> getPendingRequests() {
    return _db
        .collection('requests')
        .where('status', isEqualTo: 'تحت الإجراء')
        .snapshots();
  }

  // ─── جلب كل الطلبات (للأدمن) ───
  Stream<QuerySnapshot> getAllRequests() {
    return _db
        .collection('requests')
        .snapshots();
  }

  // ─── تحديث حالة الطلب (موافقة / رفض) ───
  Future<void> updateRequestStatus(String requestId, String newStatus, {String? adminNote}) async {
    final data = <String, dynamic>{
      'status': newStatus,
      'reviewedAt': FieldValue.serverTimestamp(),
    };
    if (adminNote != null && adminNote.isNotEmpty) {
      data['adminNote'] = adminNote;
    }
    await _db.collection('requests').doc(requestId).update(data);
  }
}
