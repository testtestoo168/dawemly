import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Queues attendance punches while offline and syncs them when connectivity
/// returns. Each punch is HMAC-signed on the device with a per-user secret
/// fetched from the server (via `users.php?action=get_offline_config`).
///
/// Security model:
///  - Server only accepts offline punches for users whose `offline_mode_enabled=1`.
///  - Each punch carries a `client_timestamp`, a monotonically increasing
///    `client_nonce`, and an HMAC-SHA256 signature.
///  - Server verifies signature + nonce (replay protection) + timestamp window
///    (<= 12h old, not in the future) + GPS geofence + per-user state.
///
/// Storage keys:
///  - `offline_queue_v1`  → JSON array of pending punches
///  - `offline_nonce`     → last issued nonce (int, per device)
///  - `offline_secret_<uid>` → the HMAC secret fetched from the server
///  - `offline_enabled_<uid>` → '1' if the server said offline mode is on
class OfflineQueueService {
  OfflineQueueService._();
  static final OfflineQueueService instance = OfflineQueueService._();

  static const _kQueue = 'offline_queue_v1';
  static const _kNonce = 'offline_nonce';
  static String _kSecret(String uid) => 'offline_secret_$uid';
  static String _kEnabled(String uid) => 'offline_enabled_$uid';

  /// Refresh offline config from server (secret, last_sync_nonce, enabled flag).
  /// Caches the result locally so GPS-only offline flows can still sign punches.
  /// Returns true when offline mode is enabled for the authenticated user.
  Future<bool> refreshConfig(String uid) async {
    final res = await ApiService.get('users.php?action=get_offline_config');
    if (res['success'] != true) return false;
    final enabled = (res['offline_mode_enabled'] == 1 || res['offline_mode_enabled'] == true);
    final secret = (res['offline_secret'] ?? '').toString();
    final lastServerNonce = (res['last_sync_nonce'] is int)
        ? res['last_sync_nonce'] as int
        : int.tryParse('${res['last_sync_nonce'] ?? 0}') ?? 0;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEnabled(uid), enabled ? '1' : '0');
    if (enabled && secret.isNotEmpty) {
      await prefs.setString(_kSecret(uid), secret);
      // Make sure local nonce counter is ahead of server's view.
      final localNonce = prefs.getInt(_kNonce) ?? 0;
      if (lastServerNonce > localNonce) {
        await prefs.setInt(_kNonce, lastServerNonce);
      }
    } else {
      await prefs.remove(_kSecret(uid));
    }
    return enabled;
  }

  /// True if the server has told us offline mode is enabled for this user
  /// and we have a usable secret cached locally. Works without network.
  Future<bool> isEnabledFor(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getString(_kEnabled(uid)) == '1';
    final secret = prefs.getString(_kSecret(uid));
    return enabled && secret != null && secret.isNotEmpty;
  }

  Future<int> _nextNonce() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kNonce) ?? 0;
    final next = current + 1;
    await prefs.setInt(_kNonce, next);
    return next;
  }

  String _sign({
    required String secret,
    required String uid,
    required String timestamp,
    required double lat,
    required double lng,
    required int nonce,
  }) {
    final message = '$uid.$timestamp.$lat.$lng.$nonce';
    return Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(message))
        .toString();
  }

  /// Save a check-in/out locally. Returns the queued entry (includes nonce).
  /// Throws [StateError] if offline mode isn't enabled or secret is missing.
  Future<Map<String, dynamic>> queuePunch({
    required String uid,
    required String empId,
    required String name,
    required String type, // 'checkIn' | 'checkOut'
    required double lat,
    required double lng,
    required double accuracy,
    String authMethod = 'fingerprint',
    String? facePhotoUrl,
    bool biometric = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final secret = prefs.getString(_kSecret(uid));
    final enabled = prefs.getString(_kEnabled(uid)) == '1';
    if (!enabled || secret == null || secret.isEmpty) {
      throw StateError('offline_not_enabled');
    }

    // Use second-precision local time in ISO-like format the PHP DateTime parser accepts.
    final now = DateTime.now();
    final ts = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    final nonce = await _nextNonce();
    final sig = _sign(
      secret: secret, uid: uid, timestamp: ts,
      lat: lat, lng: lng, nonce: nonce,
    );

    final entry = <String, dynamic>{
      'id': '${now.millisecondsSinceEpoch}_$nonce',
      'uid': uid,
      'emp_id': empId,
      'name': name,
      'type': type, // checkIn | checkOut
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'auth_method': authMethod,
      'biometric': biometric,
      if (facePhotoUrl != null) 'face_photo_url': facePhotoUrl,
      'client_timestamp': ts,
      'client_nonce': nonce,
      'offline_signature': sig,
      'queued_at': now.toIso8601String(),
    };

    final list = await _read(prefs);
    list.add(entry);
    await _write(prefs, list);
    return entry;
  }

  Future<List<Map<String, dynamic>>> _read(SharedPreferences prefs) async {
    final raw = prefs.getString(_kQueue);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _write(SharedPreferences prefs, List<Map<String, dynamic>> list) async {
    await prefs.setString(_kQueue, jsonEncode(list));
  }

  /// Count of pending punches.
  Future<int> pendingCount() async {
    final prefs = await SharedPreferences.getInstance();
    return (await _read(prefs)).length;
  }

  /// Returns all pending entries (read-only snapshot).
  Future<List<Map<String, dynamic>>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    return _read(prefs);
  }

  /// Remove a queued entry by local id (set after a successful sync).
  Future<void> clearSynced(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _read(prefs);
    list.removeWhere((e) => e['id'] == id);
    await _write(prefs, list);
  }

  /// Sync all pending entries to the server. Each entry is sent as `is_offline=true`
  /// to the normal check-in / check-out endpoints with the HMAC signature.
  ///
  /// Returns a summary: {synced, failed, total}. Successfully synced entries
  /// are removed from the queue; failed ones are left for the next attempt.
  /// If the server rejects an entry as bad (e.g. bad signature), the entry is
  /// dropped to avoid an infinite retry loop and to surface tampering early.
  Future<Map<String, int>> syncAll() async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _read(prefs);
    if (list.isEmpty) return {'synced': 0, 'failed': 0, 'total': 0};

    int synced = 0;
    int failed = 0;
    // Iterate in chronological order (lowest nonce first) for correctness.
    list.sort((a, b) {
      final an = (a['client_nonce'] ?? 0) as int;
      final bn = (b['client_nonce'] ?? 0) as int;
      return an.compareTo(bn);
    });

    final remaining = <Map<String, dynamic>>[];
    for (final entry in list) {
      final type = (entry['type'] ?? 'checkIn').toString();
      final action = type == 'checkOut' ? 'checkOut' : 'checkIn';
      final body = <String, dynamic>{
        'uid': entry['uid'],
        'emp_id': entry['emp_id'],
        'name': entry['name'],
        'lat': entry['lat'],
        'lng': entry['lng'],
        'accuracy': entry['accuracy'],
        'biometric': entry['biometric'] == true ? 1 : 0,
        'auth_method': entry['auth_method'] ?? 'fingerprint',
        'is_mocked': false,
        'is_offline': true,
        'client_timestamp': entry['client_timestamp'],
        'client_nonce': entry['client_nonce'],
        'offline_signature': entry['offline_signature'],
      };
      if (entry['face_photo_url'] != null) body['face_photo_url'] = entry['face_photo_url'];

      try {
        final res = await ApiService.post('attendance.php?action=$action', body);
        if (res['success'] == true) {
          synced++;
        } else {
          // Distinguish transient errors (network / 5xx / already checked-in) from
          // permanent rejections (bad_signature / nonce_replay / too_old).
          final err = (res['error'] ?? '').toString();
          final permanent = err.contains('bad_signature') ||
              err.contains('nonce_replay') ||
              err.contains('future_timestamp') ||
              err.contains('too_old') ||
              err.contains('invalid_timestamp') ||
              err.contains('missing_offline_fields');
          if (permanent) {
            // Drop it — will never succeed.
            failed++;
          } else {
            remaining.add(entry);
            failed++;
          }
        }
      } catch (_) {
        // Network error — keep for next attempt.
        remaining.add(entry);
        failed++;
      }
    }

    await _write(prefs, remaining);
    return {'synced': synced, 'failed': failed, 'total': list.length};
  }

  /// Clear everything (useful for testing / admin reset). Does NOT clear the
  /// nonce counter — it must remain monotonic for replay protection.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQueue);
  }
}
