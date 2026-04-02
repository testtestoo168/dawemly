import 'dart:async';
import 'api_service.dart';

/// Fetches server time once and maintains an offset so the app
/// always shows/uses server time regardless of device clock.
class ServerTimeService {
  static final ServerTimeService _instance = ServerTimeService._();
  factory ServerTimeService() => _instance;
  ServerTimeService._();

  Duration _offset = Duration.zero;
  bool _synced = false;
  Timer? _syncTimer;

  /// Returns current server time (device time + offset)
  DateTime get now => DateTime.now().add(_offset);

  bool get synced => _synced;

  /// Sync with server. Call once at app start, then periodically.
  Future<void> sync() async {
    try {
      final before = DateTime.now();
      final res = await ApiService.get('auth.php?action=time');
      final after = DateTime.now();
      if (res['success'] == true && res['server_time'] != null) {
        final serverTime = DateTime.parse(res['server_time'].toString());
        // Account for network latency (half round-trip)
        final latency = after.difference(before) ~/ 2;
        final adjustedServer = serverTime.add(latency);
        _offset = adjustedServer.difference(after);
        _synced = true;
      }
    } catch (_) {
      // Keep previous offset if sync fails
    }
  }

  /// Start periodic sync every 5 minutes
  void startPeriodicSync() {
    _syncTimer?.cancel();
    sync();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => sync());
  }

  void dispose() {
    _syncTimer?.cancel();
  }
}
