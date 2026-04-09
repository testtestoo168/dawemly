import 'api_service.dart';

class RequestsService {
  // ─── إنشاء طلب إجازة ───
  Future<Map<String, dynamic>> createLeaveRequest({
    required String uid,
    required String empId,
    required String name,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    final days = endDate.difference(startDate).inDays + 1;
    final result = await ApiService.post('requests.php?action=leave', {
      'uid': uid,
      'emp_id': empId,
      'name': name,
      'leave_type': leaveType,
      'start_date': startDate.toIso8601String().substring(0, 10),
      'end_date': endDate.toIso8601String().substring(0, 10),
      'days': days,
      'reason': reason,
    });
    return result['success'] == true
        ? {'success': true, 'id': result['id'], 'days': days}
        : {'success': false, 'error': result['error'] ?? 'فشل إرسال الطلب'};
  }

  // ─── إنشاء طلب إذن ───
  Future<Map<String, dynamic>> createPermissionRequest({
    required String uid,
    required String empId,
    required String name,
    required String permType,
    required String fromTime,
    required String toTime,
    required DateTime date,
    required String reason,
    int? fromMinutes,
    int? toMinutes,
  }) async {
    double hours = 0;
    if (fromMinutes != null && toMinutes != null && toMinutes > fromMinutes) {
      hours = (toMinutes - fromMinutes) / 60.0;
    }
    final result = await ApiService.post('requests.php?action=permission', {
      'uid': uid,
      'emp_id': empId,
      'name': name,
      'perm_type': permType,
      'from_time': fromTime,
      'to_time': toTime,
      'date': date.toIso8601String().substring(0, 10),
      'reason': reason,
      'hours': hours,
    });
    return result['success'] == true
        ? {'success': true, 'id': result['id'], 'hours': hours}
        : {'success': false, 'error': result['error'] ?? 'فشل إرسال الطلب'};
  }

  // ─── طلبات الموظف ───
  Future<List<Map<String, dynamic>>> getMyRequests(String uid) async {
    final result = await ApiService.get('requests.php?action=my', params: {'uid': uid});
    if (result['success'] == true) {
      return (result['requests'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── الطلبات المعلقة (أدمن) ───
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final result = await ApiService.get('requests.php?action=pending');
    if (result['success'] == true) {
      return (result['requests'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── كل الطلبات (أدمن) ───
  Future<List<Map<String, dynamic>>> getAllRequests() async {
    final result = await ApiService.get('requests.php?action=all');
    if (result['success'] == true) {
      return (result['requests'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    return [];
  }

  // ─── تحديث حالة الطلب ───
  Future<void> updateRequestStatus(
    String requestId,
    String newStatus, {
    String? adminNote,
  }) async {
    await ApiService.post('requests.php?action=update_status', {
      'id': requestId,
      'status': newStatus,
      if (adminNote != null && adminNote.isNotEmpty) 'admin_note': adminNote,
    });
  }
}
