import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service realtime untuk attendance_records menggunakan Supabase Realtime.
///
/// Menggunakan Postgres Changes (WebSocket) — hanya menerima data saat ada
/// INSERT, UPDATE, atau DELETE pada record pegawai hari ini.
/// Zero polling, hemat bandwidth & baterai.
///
/// Fitur:
/// - Realtime via WebSocket (bukan polling)
/// - Lifecycle-aware (pause saat app di-background)
/// - Auto-reconnect saat app kembali ke foreground
/// - Fallback fetch jika realtime miss event
///
/// Contoh:
/// ```dart
/// final service = AttendanceRealtimeService(employeeId: 'emp123');
/// service.onDataChanged.addListener(() {
///   final data = service.onDataChanged.value;
///   // Update UI
/// });
/// service.subscribe();
/// ```
class AttendanceRealtimeService with WidgetsBindingObserver {
  final String employeeId;

  RealtimeChannel? _channel;
  final _dataChangedController = ValueNotifier<Map<String, dynamic>?>(null);
  final _loadingController = ValueNotifier<bool>(false);
  final _errorController = ValueNotifier<String?>(null);
  bool _isSubscribed = false;
  bool _isInBackground = false;

  AttendanceRealtimeService({required this.employeeId});

  /// Notifier untuk perubahan data absensi.
  /// null = belum absen hari ini, Map = data record.
  ValueNotifier<Map<String, dynamic>?> get onDataChanged => _dataChangedController;

  /// Loading state.
  ValueNotifier<bool> get loading => _loadingController;

  /// Error message jika ada.
  ValueNotifier<String?> get error => _errorController;

  /// Subscribe ke Supabase Realtime channel.
  ///
  /// Akan listen INSERT, UPDATE, DELETE pada attendance_records
  /// untuk employee ini pada tanggal hari ini.
  Future<void> subscribe() async {
    if (_isSubscribed) return;

    try {
      _loadingController.value = true;
      _errorController.value = null;

      // Register lifecycle observer
      WidgetsBinding.instance.addObserver(this);

      // Fetch initial data
      await _fetchTodayRecord();

      // Setup realtime channel
      _setupRealtimeChannel();

      _isSubscribed = true;
      _loadingController.value = false;

      debugPrint('[AttendanceRealtime] Subscribed (Realtime WebSocket)');
    } catch (e) {
      debugPrint('[AttendanceRealtime] Subscribe error: $e');
      _errorController.value = 'Gagal subscribe: $e';
      _loadingController.value = false;
    }
  }

  /// Setup Supabase Realtime channel untuk Postgres Changes.
  void _setupRealtimeChannel() {
    final today = _todayString();

    _channel = SupabaseService.client
        .channel('attendance_$employeeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'employee_id',
            value: employeeId,
          ),
          callback: (payload) {
            _handleRealtimeEvent(payload, today);
          },
        )
        .subscribe((status, [error]) {
      debugPrint('[AttendanceRealtime] Channel status: $status');
      if (status == RealtimeSubscribeStatus.channelError) {
        _errorController.value = 'Realtime channel error';
        debugPrint('[AttendanceRealtime] Channel error: $error');
      }
    });
  }

  /// Handle event dari Realtime channel.
  void _handleRealtimeEvent(PostgresChangePayload payload, String today) {
    try {
      final eventType = payload.eventType;
      debugPrint('[AttendanceRealtime] Event: $eventType');

      if (eventType == PostgresChangeEvent.delete) {
        // Record dihapus — cek apakah itu record hari ini
        final oldRecord = payload.oldRecord;
        if (oldRecord['tanggal'] == today) {
          _dataChangedController.value = null;
          debugPrint('[AttendanceRealtime] Record deleted');
        }
        return;
      }

      // INSERT atau UPDATE
      final newRecord = payload.newRecord;
      if (newRecord['tanggal'] == today) {
        // Fetch ulang dengan join divisions untuk dapat nama divisi
        _fetchTodayRecord();
      }
    } catch (e) {
      debugPrint('[AttendanceRealtime] Handle event error: $e');
      // Fallback: fetch ulang
      _fetchTodayRecord();
    }
  }

  /// Fetch record absensi hari ini (initial load + fallback).
  Future<void> _fetchTodayRecord() async {
    try {
      await SupabaseService.ensureAuthenticated();

      final today = _todayString();

      final response = await SupabaseService.client
          .from('attendance_records')
          .select('*, divisions:division_id(nama)')
          .eq('employee_id', employeeId)
          .eq('tanggal', today)
          .maybeSingle();

      if (response != null) {
        _dataChangedController.value = Map<String, dynamic>.from(response);
      } else {
        _dataChangedController.value = null;
      }

      _errorController.value = null;
    } catch (e) {
      debugPrint('[AttendanceRealtime] Fetch error: $e');
      _errorController.value = 'Gagal mengambil data: $e';
    }
  }

  /// Manual refresh (untuk pull-to-refresh).
  Future<void> refresh() async {
    _loadingController.value = true;
    await _fetchTodayRecord();
    _loadingController.value = false;
  }

  /// Unsubscribe dari realtime channel.
  Future<void> unsubscribe() async {
    if (!_isSubscribed) return;

    try {
      if (_channel != null) {
        await SupabaseService.client.removeChannel(_channel!);
        _channel = null;
      }
      WidgetsBinding.instance.removeObserver(this);
      _isSubscribed = false;
      debugPrint('[AttendanceRealtime] Unsubscribed');
    } catch (e) {
      debugPrint('[AttendanceRealtime] Unsubscribe error: $e');
    }
  }

  /// Cleanup semua resources.
  void dispose() {
    unsubscribe();
    _dataChangedController.dispose();
    _loadingController.dispose();
    _errorController.dispose();
  }

  // ═══════════════════════════════════════════════════════
  // LIFECYCLE AWARENESS
  // ═══════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        _onBackground();
        break;
      case AppLifecycleState.resumed:
        _onForeground();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }

  /// App masuk background — channel tetap aktif (WebSocket lightweight).
  void _onBackground() {
    _isInBackground = true;
    debugPrint('[AttendanceRealtime] App backgrounded');
  }

  /// App kembali ke foreground — fetch ulang untuk pastikan data fresh.
  void _onForeground() {
    if (_isInBackground && _isSubscribed) {
      _isInBackground = false;
      debugPrint('[AttendanceRealtime] App resumed — refreshing data');
      _fetchTodayRecord();
    }
  }

  // ═══════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════

  String _todayString() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }
}
