import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:untitled/services/chat_service.dart';
import 'package:untitled/services/transaction_service.dart';
import 'package:untitled/services/notification_service.dart';

void main() {
  late FirebaseFirestore mockFirestore;
  late ChatService chatService;
  late TransactionService transactionService;
  late NotificationService notificationService;

  setUp(() async {
    await Firebase.initializeApp();
    mockFirestore = FirebaseFirestore.instance;
  });

  group('Session Booking Flow Tests', () {
    test('Should handle insufficient balance error', () async {
      // Setup test data
      const String userId = 'test_user';
      const String astrologerId = 'test_astrologer';

      try {
        await ChatService.createPaidChatSession(
          userId,
          astrologerId,
          sessionType: 'text',
        );
        fail('Should throw insufficient balance error');
      } catch (e) {
        expect(e.toString(), contains('insufficient balance'));
      }
    });

    test('Should handle invalid session type', () async {
      const String userId = 'test_user';
      const String astrologerId = 'test_astrologer';

      try {
        await ChatService.createPaidChatSession(
          userId,
          astrologerId,
          sessionType: 'invalid_type',
        );
        fail('Should throw invalid session type error');
      } catch (e) {
        expect(e.toString(), contains('invalid session type'));
      }
    });

    test('Should handle concurrent session requests', () async {
      const String userId = 'test_user';
      const String astrologerId = 'test_astrologer';

      // Create first session
      final firstSessionId = await ChatService.createPaidChatSession(
        userId,
        astrologerId,
        sessionType: 'text',
      );

      try {
        // Try to create second session while first is active
        await ChatService.createPaidChatSession(
          userId,
          astrologerId,
          sessionType: 'text',
        );
        fail('Should throw concurrent session error');
      } catch (e) {
        expect(e.toString(), contains('active session exists'));
      }
    });

    test('Should handle session cancellation', () async {
      const String userId = 'test_user';
      const String astrologerId = 'test_astrologer';

      // Create and cancel session
      final sessionId = await ChatService.createPaidChatSession(
        userId,
        astrologerId,
        sessionType: 'text',
      );

      if (sessionId != null) {
        await ChatService.cancelPaidChatSession(
          sessionId,
          'user requested cancellation',
        );

        // Verify session status
        final cancelledSession =
            await mockFirestore
                .collection('chat_sessions')
                .doc(sessionId)
                .get();

        expect(cancelledSession.get('status'), equals('cancelled'));
      } else {
        fail('Session not created');
      }
    });

    test('Should handle payment processing errors', () async {
      const String userId = 'test_user';
      const String astrologerId = 'test_astrologer';

      // Create session
      final sessionId = await ChatService.createPaidChatSession(
        userId,
        astrologerId,
        sessionType: 'text',
      );

      if (sessionId != null) {
        try {
          // Simulate payment processing error
          await TransactionService.addTransaction(
            userId,
            -50.0, // استخدام قيمة ثابتة للاختبار بدلاً من sessionRate
            'payment',
          );
          fail('Should throw payment processing error');
        } catch (e) {
          expect(e.toString(), contains('payment processing failed'));

          // Verify session status is updated
          final failedSession =
              await mockFirestore
                  .collection('chat_sessions')
                  .doc(sessionId)
                  .get();
          expect(failedSession.get('status'), equals('payment_failed'));
        }
      } else {
        fail('Session not created');
      }
    });

    test('Should validate rate calculations', () async {
      const String userId = 'test_user';
      const String astrologerId = 'test_astrologer';
      const int durationMinutes = 30;

      // Create and complete session
      final sessionId = await ChatService.createPaidChatSession(
        userId,
        astrologerId,
        sessionType: 'text',
      );

      if (sessionId != null) {
        await ChatService.acceptPaidChatSession(sessionId);

        // Fast forward time
        await Future.delayed(const Duration(minutes: durationMinutes));

        await ChatService.endPaidChatSession(sessionId);

        // Verify session completion
        final completedSession =
            await mockFirestore
                .collection('chat_sessions')
                .doc(sessionId)
                .get();

        // التحقق من أن التكلفة الإجمالية تم حسابها
        expect(completedSession.get('total_cost'), isNotNull);
        expect(completedSession.get('total_duration'), equals(durationMinutes));
      } else {
        fail('Session not created');
      }
    });
  });
}
