import 'package:committee_app/core/models/committee.dart';
import 'package:committee_app/core/providers/service_providers.dart';
import 'package:committee_app/features/auth/data/auth_service.dart';
import 'package:committee_app/screens/host/host_dashboard_screen.dart';
import 'package:committee_app/services/auto_sync_service.dart';
import 'package:committee_app/services/database_service.dart';
import 'package:committee_app/services/realtime_sync_service.dart';
import 'package:committee_app/services/sync_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:committee_app/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

// Generate mocks
@GenerateMocks([
  AuthService,
  DatabaseService,
  SyncService,
  AutoSyncService,
  RealtimeSyncService,
  User,
])
import 'host_dashboard_test.mocks.dart';

void main() {
  late MockAuthService mockAuthService;
  late MockDatabaseService mockDatabaseService;
  late MockSyncService mockSyncService;
  late MockAutoSyncService mockAutoSyncService;
  late MockRealtimeSyncService mockRealtimeSyncService;
  late MockUser mockUser;

  setUp(() {
    mockAuthService = MockAuthService();
    mockDatabaseService = MockDatabaseService();
    mockSyncService = MockSyncService();
    mockAutoSyncService = MockAutoSyncService();
    mockRealtimeSyncService = MockRealtimeSyncService();
    mockUser = MockUser();

    // Default setups
    when(mockAuthService.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_host_id');
    when(mockUser.emailVerified).thenReturn(true);
    when(mockUser.email).thenReturn('host@test.com');
    when(mockUser.displayName).thenReturn('Test Host');

    when(mockDatabaseService.getHostedCommittees(any)).thenReturn([]);
    when(mockSyncService.syncAll(any))
        .thenAnswer((_) async => SyncResult(success: true, message: 'Synced'));

    when(mockRealtimeSyncService.addListener(any)).thenReturn(null);
    when(mockRealtimeSyncService.removeListener(any)).thenReturn(null);
    when(mockRealtimeSyncService.startListening(any)).thenReturn(null);
    when(mockRealtimeSyncService.stopListening()).thenReturn(null);
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        databaseServiceProvider.overrideWithValue(mockDatabaseService),
        syncServiceProvider.overrideWithValue(mockSyncService),
        autoSyncServiceProvider.overrideWithValue(mockAutoSyncService),
        realtimeSyncServiceProvider.overrideWithValue(mockRealtimeSyncService),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: HostDashboardScreen(),
      ),
    );
  }

  testWidgets('HostDashboard displays empty state when no committees exist',
      (tester) async {
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle(); // Wait for animations and sync

    expect(find.text('No Committees Yet'), findsOneWidget);
    expect(find.text('Create your first committee to get started'),
        findsOneWidget);
    expect(find.text('New Committee'), findsOneWidget);
  });

  testWidgets('HostDashboard displays committees when data exists',
      (tester) async {
    final committee = Committee(
      id: '1',
      code: '123456',
      name: 'Test Kameti',
      hostId: 'test_host_id',
      contributionAmount: 1000.0,
      frequency: 'monthly',
      startDate: DateTime.now(),
      totalMembers: 10,
      createdAt: DateTime.now(),
    );
    when(mockDatabaseService.getHostedCommittees('test_host_id'))
        .thenReturn([committee]);
    when(mockDatabaseService.getMembersByCommittee('1')).thenReturn([]);

    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    expect(find.text('Test Kameti'), findsOneWidget);
    expect(find.text('No Committees Yet'), findsNothing);
  });
}
