import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:committee_app/services/database_service.dart';
import 'package:committee_app/features/auth/data/auth_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStateProvider = StreamProvider((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});
