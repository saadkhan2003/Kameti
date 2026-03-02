import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'toast_service.dart';

/// Sync status states
enum SyncState {
  synced,   // All data synced with cloud (green)
  syncing,  // Actively syncing right now (blue, animated)
  pending,  // Has unsynced local changes (orange)
  offline,  // No internet connection (grey)
  error,    // Last sync failed (red)
}

/// A ChangeNotifier that tracks the current sync state across the app.
/// Shows floating toasts when state changes (Google Docs / Figma style).
class SyncStatusService extends ChangeNotifier {
  static final SyncStatusService _instance = SyncStatusService._internal();
  factory SyncStatusService() => _instance;
  SyncStatusService._internal() {
    _monitorConnectivity();
  }

  SyncState _state = SyncState.synced;
  int _pendingCount = 0;
  String _lastError = '';
  DateTime? _lastSyncedAt;
  bool _isOnline = true;
  StreamSubscription? _connectivitySub;
  Timer? _syncingToastTimer;

  // Global key for showing toasts without context
  static GlobalKey<NavigatorState>? navigatorKey;

  // Getters
  SyncState get state => _state;
  int get pendingCount => _pendingCount;
  String get lastError => _lastError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool get isOnline => _isOnline;

  /// Human-readable status label
  String get statusLabel {
    switch (_state) {
      case SyncState.synced:
        return 'Synced';
      case SyncState.syncing:
        return 'Syncing...';
      case SyncState.pending:
        return '$_pendingCount pending';
      case SyncState.offline:
        return 'Offline';
      case SyncState.error:
        return 'Sync failed';
    }
  }

  // ============ STATE UPDATES ============

  /// Called when a sync operation starts
  void setSyncing() {
    _state = SyncState.syncing;
    notifyListeners();

    // Only show "Syncing..." toast if it takes > 2 seconds
    _syncingToastTimer?.cancel();
    _syncingToastTimer = Timer(const Duration(seconds: 2), () {
      if (_state == SyncState.syncing) {
        _showToast('Syncing your data...', ToastType.info);
      }
    });
  }

  /// Called when sync completes successfully
  void setSynced() {
    _syncingToastTimer?.cancel();
    final prevState = _state;
    _state = SyncState.synced;
    _pendingCount = 0;
    _lastError = '';
    _lastSyncedAt = DateTime.now();
    notifyListeners();

    // Only show toast if we were in a notable state before
    if (prevState == SyncState.error || prevState == SyncState.offline || prevState == SyncState.pending) {
      _showToast('All changes synced', ToastType.success);
    }
  }

  /// Called when sync fails
  void setError(String error) {
    _syncingToastTimer?.cancel();
    if (_isOnline) {
      _state = SyncState.error;
      _lastError = error;
      _showToast('Sync failed — tap cloud icon to retry', ToastType.error);
    } else {
      _state = SyncState.offline;
    }
    notifyListeners();
  }

  /// Called when a local change is saved but not yet synced
  void addPendingChange() {
    _pendingCount++;
    if (_state != SyncState.syncing) {
      final prevState = _state;
      _state = _isOnline ? SyncState.pending : SyncState.offline;

      // Show offline toast only on first transition
      if (_state == SyncState.offline && prevState != SyncState.offline) {
        _showToast('You\'re offline — changes saved locally', ToastType.warning);
      }
    }
    notifyListeners();
  }

  /// Called when pending changes are resolved
  void clearPending() {
    _pendingCount = 0;
    if (_state == SyncState.pending) {
      _state = SyncState.synced;
    }
    notifyListeners();
  }

  // ============ TOAST HELPER ============

  void _showToast(String message, ToastType type) {
    try {
      final overlay = navigatorKey?.currentState?.overlay;
      if (overlay == null) return;
      ToastService.show(overlay.context, message, type: type, duration: const Duration(seconds: 2));
    } catch (e) {
      // Overlay not ready yet — silently skip
    }
  }

  // ============ CONNECTIVITY MONITORING ============

  void _monitorConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;

      // connectivity_plus returns List<ConnectivityResult>
      final results = (result as List).cast<ConnectivityResult>();
      _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);

      if (!_isOnline && wasOnline) {
        _state = SyncState.offline;
        _showToast('You\'re offline — changes saved locally', ToastType.warning);
        notifyListeners();
      } else if (_isOnline && !wasOnline) {
        // Came back online
        if (_pendingCount > 0) {
          _state = SyncState.pending;
          _showToast('Back online — syncing pending changes...', ToastType.info);
        } else {
          _state = SyncState.synced;
          _showToast('Back online', ToastType.success);
        }
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _syncingToastTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
