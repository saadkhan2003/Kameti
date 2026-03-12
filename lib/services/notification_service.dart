import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> notifyNewProof({
    required String hostId,
    required String memberName,
    required String monthLabel,
    required String amountLabel,
  }) async {
    await _invokeNotification(
      event: 'proof_uploaded',
      payload: {
        'recipient_user_id': hostId,
        'title': 'New Payment Proof',
        'body': '$memberName uploaded proof for $monthLabel — $amountLabel',
      },
    );
  }

  Future<void> notifyProofApproved({
    required String memberId,
    required String monthLabel,
  }) async {
    await _invokeNotification(
      event: 'proof_approved',
      payload: {
        'recipient_user_id': memberId,
        'title': 'Payment Approved',
        'body': 'Your $monthLabel payment proof has been approved!',
      },
    );
  }

  Future<void> notifyProofRejected({
    required String memberId,
    required String reason,
  }) async {
    await _invokeNotification(
      event: 'proof_rejected',
      payload: {
        'recipient_user_id': memberId,
        'title': 'Proof Rejected',
        'body': 'Reason: $reason. Tap to resubmit.',
      },
    );
  }

  Future<void> _invokeNotification({
    required String event,
    required Map<String, dynamic> payload,
  }) async {
    try {
      await _client.functions.invoke(
        'send-payment-proof-notification',
        body: {'event': event, ...payload},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Notification function unavailable: $e');
      }
    }
  }
}
