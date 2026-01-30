import 'package:committee_app/features/auth/data/auth_service.dart';
import 'package:committee_app/services/auto_sync_service.dart';
import 'package:committee_app/services/database_service.dart';
import 'package:committee_app/services/realtime_sync_service.dart';
import 'package:committee_app/services/sync_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    dbService: ref.watch(databaseServiceProvider),
  );
});

final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  return RealtimeSyncService(
    dbService: ref.watch(databaseServiceProvider),
  );
});

final autoSyncServiceProvider = Provider<AutoSyncService>((ref) {
  return AutoSyncService(
    syncService: ref.watch(syncServiceProvider),
    dbService: ref.watch(databaseServiceProvider),
    realtimeSyncService: ref.watch(realtimeSyncServiceProvider),
  );
});
