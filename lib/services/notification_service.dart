import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../supabase_config.dart';

class NotificationService {
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
    // Use the anon key directly via HTTP so it works for both
    // authenticated hosts and anonymous members (who join via code)
    final supabaseUrl = SupabaseConfig.url;
    final anonKey = SupabaseConfig.anonKey;

    final body = {'event': event, ...payload};

    debugPrint('🔔 Invoking notification: $event');
    debugPrint('🔔 Supabase URL: $supabaseUrl');
    debugPrint('🔔 Recipient: ${payload['recipient_user_id']}');

    // always call the Edge Function via HTTP using the anon key. The
    // Supabase client will automatically attach whatever JWT it has in
    // its store; on web this is often an expired or anonymous token which
    // results in a 401 "Invalid JWT" error, so we avoid it entirely.
    try {
      final uri = Uri.parse(
        '$supabaseUrl/functions/v1/send-payment-proof-notification',
      );
      debugPrint('🔁 HTTP POST to $uri');
      final httpResp = await http.post(
        uri,
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      debugPrint('🔁 HTTP response status: ${httpResp.statusCode}');
      debugPrint('🔁 HTTP response body: ${httpResp.body}');
    } catch (e, st) {
      debugPrint('⚠️ HTTP invocation failed: $e');
      debugPrint(st.toString());
      // network error, CORS, etc.
    }
  }
}
