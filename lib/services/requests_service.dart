import 'api_service.dart';

class RequestsService {
  // ─── Create leave request ───
  Future<Map<String, dynamic>> createLeaveRequest({
    required String uid,
    required String empId,
    required String name,
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    try {
      final result = await ApiService.post('requests.php?action=leave', body: {
        'leave_type': leaveType,
        'start_date': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
        'end_date': '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}',
        'reason': reason,
      });
      return {'success': true, ...result};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Create permission request ───
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
    try {
      final result = await ApiService.post('requests.php?action=permission', body: {
        'perm_type': permType,
        'from_time': fromTime,
        'to_time': toTime,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'reason': reason,
        'from_minutes': fromMinutes,
        'to_minutes': toMinutes,
      });
      return {'success': true, ...result};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ─── Get my requests ───
  Future<List<Map<String, dynamic>>> getMyRequests(String uid) async {
    try {
      final result = await ApiService.get('requests.php?action=my');
      final list = result['requests'] ?? result['data'] ?? [];
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Get pending requests (admin) ───
  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final result = await ApiService.get('requests.php?action=pending');
      final list = result['requests'] ?? result['data'] ?? [];
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Get all requests (admin) ───
  Future<List<Map<String, dynamic>>> getAllRequests() async {
    try {
      final result = await ApiService.get('requests.php?action=all');
      final list = result['requests'] ?? result['data'] ?? [];
      return (list as List).map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Update request status (admin) + send notification to employee ───
  Future<void> updateRequestStatus(String requestId, String newStatus, {String? adminNote}) async {
    await ApiService.post('requests.php?action=update_status', body: {
      'request_id': requestId,
      'status': newStatus,
      'admin_note': adminNote ?? '',
    });
  }

  // ─── Send notification to admins when employee submits request ───
  Future<void> notifyAdminsNewRequest(String requestType, String employeeName) async {
    try {
      await ApiService.post('admin.php?action=send_notification', body: {
        'uid': 'all_admins',
        'title': 'طلب جديد',
        'body': '$employeeName قدم طلب $requestType جديد',
        'type': 'info',
      });
    } catch (_) {}
  }

  // ─── Send notification to employee when admin responds ───
  Future<void> notifyEmployeeRequestUpdate(String employeeUid, String status, String requestType) async {
    try {
      final title = status == 'تم الموافقة' ? 'تمت الموافقة ✅' : 'تم الرفض ❌';
      final body = status == 'تم الموافقة'
          ? 'تمت الموافقة على طلب $requestType الخاص بك'
          : 'تم رفض طلب $requestType الخاص بك';
      await ApiService.post('admin.php?action=send_notification', body: {
        'uid': employeeUid,
        'title': title,
        'body': body,
        'type': status == 'تم الموافقة' ? 'info' : 'alert',
      });
    } catch (_) {}
  }
}
