import 'package:committee_app/core/models/committee.dart';
import 'package:committee_app/services/database_service.dart';
import 'package:committee_app/services/sync_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([DatabaseService])
import 'sync_service_test.mocks.dart';

void main() {
  late SyncService syncService;
  late FakeFirebaseFirestore fakeFirestore;
  late MockDatabaseService mockDbService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockDbService = MockDatabaseService();
    syncService = SyncService(
      firestore: fakeFirestore,
      dbService: mockDbService,
    );
  });

  group('SyncService - Committees', () {
    test('syncCommittees uploads local committees to Firestore', () async {
      // Arrange
      final committee = Committee(
        id: '1',
        code: '123456',
        name: 'Test Kameti',
        hostId: 'host1',
        contributionAmount: 1000,
        frequency: 'monthly',
        startDate: DateTime(2023, 1, 1),
        totalMembers: 10,
        createdAt: DateTime(2023, 1, 1),
      );

      when(mockDbService.getHostedCommittees('host1')).thenReturn([committee]);
      when(mockDbService.getCommitteeById('1')).thenReturn(committee);

      // Act
      await syncService.syncCommittees('host1');

      // Assert
      final snapshot = await fakeFirestore.collection('committees').doc('1').get();
      expect(snapshot.exists, true);
      expect(snapshot.data()?['name'], 'Test Kameti');
    });

    test('syncCommittees downloads newer committees from Firestore', () async {
      // Arrange
      final cloudCommittee = Committee(
        id: '2',
        code: '654321',
        name: 'Cloud Kameti',
        hostId: 'host1',
        contributionAmount: 2000,
        frequency: 'monthly',
        startDate: DateTime(2023, 2, 1),
        totalMembers: 5,
        createdAt: DateTime(2023, 2, 1),
      );

      // Add to fake firestore
      await fakeFirestore
          .collection('committees')
          .doc('2')
          .set(cloudCommittee.toJson());

      // Local db returns empty or old
      when(mockDbService.getHostedCommittees('host1')).thenReturn([]);
      when(mockDbService.getCommitteeById('2')).thenReturn(null);

      // Act
      final result = await syncService.syncCommittees('host1');

      // Assert
      verify(mockDbService.saveCommittee(any)).called(1);
      expect(result.downloaded, 1);
    });
  });
}
