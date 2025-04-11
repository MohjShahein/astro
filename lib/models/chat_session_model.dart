import 'package:cloud_firestore/cloud_firestore.dart';

class ChatSessionModel {
  final String id;
  final String userId;
  final String astrologerId;
  final List<String> participants;
  final String status;
  final DateTime createdAt;
  final DateTime? startTime;
  final DateTime? endTime;
  final String sessionType;
  final double ratePerMinute;
  final bool isPaid;
  final bool isFreeSession;
  final double totalDuration;
  final double totalCost;
  final double freeSessionLimit;
  final String? cancellationReason;

  ChatSessionModel({
    required this.id,
    required this.userId,
    required this.astrologerId,
    required this.participants,
    required this.status,
    required this.createdAt,
    this.startTime,
    this.endTime,
    required this.sessionType,
    required this.ratePerMinute,
    required this.isPaid,
    required this.isFreeSession,
    required this.totalDuration,
    required this.totalCost,
    required this.freeSessionLimit,
    this.cancellationReason,
  });

  factory ChatSessionModel.fromMap(String id, Map<String, dynamic> map) {
    return ChatSessionModel(
      id: id,
      userId: map['user_id'] as String,
      astrologerId: map['astrologer_id'] as String,
      participants: List<String>.from(map['participants'] ?? []),
      status: map['status'] as String,
      createdAt: (map['created_at'] as Timestamp).toDate(),
      startTime: map['start_time'] != null
          ? (map['start_time'] as Timestamp).toDate()
          : null,
      endTime: map['end_time'] != null
          ? (map['end_time'] as Timestamp).toDate()
          : null,
      sessionType: map['session_type'] as String,
      ratePerMinute: (map['rate_per_minute'] as num).toDouble(),
      isPaid: map['is_paid'] as bool,
      isFreeSession: map['is_free_session'] as bool,
      totalDuration: (map['total_duration'] as num).toDouble(),
      totalCost: (map['total_cost'] as num).toDouble(),
      freeSessionLimit: (map['free_session_limit'] as num).toDouble(),
      cancellationReason: map['cancellation_reason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'astrologer_id': astrologerId,
      'participants': participants,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      'start_time': startTime != null ? Timestamp.fromDate(startTime!) : null,
      'end_time': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'session_type': sessionType,
      'rate_per_minute': ratePerMinute,
      'is_paid': isPaid,
      'is_free_session': isFreeSession,
      'total_duration': totalDuration,
      'total_cost': totalCost,
      'free_session_limit': freeSessionLimit,
      'cancellation_reason': cancellationReason,
    };
  }

  // طريقة مساعدة للحصول على تاريخ بدء الجلسة بتنسيق آمن
  String getFormattedStartTime() {
    try {
      if (startTime != null) {
        return '${startTime!.year}-${startTime!.month.toString().padLeft(2, '0')}-${startTime!.day.toString().padLeft(2, '0')} ${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('خطأ في تنسيق وقت البدء: $e');
    }
    return 'غير متاح';
  }

  // طريقة مساعدة للحصول على مدة الجلسة بتنسيق مناسب
  String getFormattedDuration() {
    if (totalDuration <= 0) return 'غير متاح';
    if (totalDuration < 60) return '$totalDuration دقيقة';
    final hours = totalDuration ~/ 60;
    final minutes = totalDuration % 60;
    if (minutes == 0) return '$hours ساعة';
    return '$hours ساعة و $minutes دقيقة';
  }

  // طريقة مساعدة للحصول على الوقت المقدر المتبقي لانتظار جلسة معلقة
  String getEstimatedWaitTime() {
    // متوسط مدة الجلسة - مقدر ب 30 دقيقة أو مدة محددة من النظام
    const int averageSessionDuration = 30; // بالدقائق

    // الوقت المتبقي للجلسة المعلقة هو تقدير بناءً على متوسط مدة الجلسات
    return '$averageSessionDuration دقيقة تقريباً';
  }

  // طريقة مساعدة لعرض سبب الإلغاء إن وجد
  String getCancellationReason() {
    return cancellationReason ?? 'لم يتم تحديد سبب';
  }
}
