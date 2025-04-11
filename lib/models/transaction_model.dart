import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String
      transactionType; // 'deposit', 'payment', 'refund', 'partial_refund', 'earning'
  final DateTime createdAt;
  final String? sessionId;
  final String? sessionTitle;
  final String? otherPartyId; // معرف الطرف الآخر في المعاملة (إذا كان موجودًا)
  final String? description; // وصف اختياري للمعاملة

  TransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.transactionType,
    required this.createdAt,
    this.sessionId,
    this.sessionTitle,
    this.otherPartyId,
    this.description,
  });

  factory TransactionModel.fromMap(String id, Map<String, dynamic> data) {
    return TransactionModel(
      id: id,
      userId: data['user_id'] ?? '',
      amount:
          (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0,
      transactionType: data['transaction_type'] ?? data['type'] ?? 'unknown',
      createdAt: (data['created_at'] is Timestamp)
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      sessionId: data['session_id'],
      sessionTitle: data['session_title'],
      otherPartyId: data['other_party_id'],
      description: data['description'],
    );
  }

  String get typeInArabic {
    switch (transactionType) {
      case 'deposit':
        return 'إيداع رصيد';
      case 'payment':
        return 'دفع للجلسة';
      case 'refund':
        return 'استرداد كامل';
      case 'partial_refund':
        return 'استرداد جزئي';
      case 'earning':
        return 'أرباح من جلسة';
      case 'withdrawal':
        return 'سحب رصيد';
      case 'bonus':
        return 'مكافأة';
      case 'admin_adjustment':
        return 'تعديل إداري';
      default:
        return 'معاملة: $transactionType';
    }
  }

  String get shortDescription {
    if (description != null && description!.isNotEmpty) {
      return description!;
    }

    if (sessionId != null) {
      if (sessionTitle != null && sessionTitle!.isNotEmpty) {
        return 'جلسة: $sessionTitle';
      }
      return 'معرف الجلسة: $sessionId';
    }

    return typeInArabic;
  }

  bool get isPositive => amount > 0;

  String get formattedAmount =>
      '${isPositive ? "+" : ""}${amount.toStringAsFixed(1)}';

  IconData get icon {
    switch (transactionType) {
      case 'deposit':
        return isPositive ? Icons.account_balance_wallet : Icons.money_off;
      case 'payment':
        return Icons.payments;
      case 'refund':
      case 'partial_refund':
        return Icons.assignment_return;
      case 'earning':
        return Icons.monetization_on;
      case 'withdrawal':
        return Icons.attach_money;
      case 'bonus':
        return Icons.card_giftcard;
      case 'admin_adjustment':
        return Icons.admin_panel_settings;
      default:
        return isPositive ? Icons.add_circle : Icons.remove_circle;
    }
  }

  Color get color {
    switch (transactionType) {
      case 'deposit':
        return Colors.green;
      case 'payment':
        return Colors.red;
      case 'refund':
      case 'partial_refund':
        return Colors.orange;
      case 'earning':
        return Colors.green;
      case 'withdrawal':
        return Colors.redAccent;
      case 'bonus':
        return Colors.purple;
      case 'admin_adjustment':
        return Colors.blue;
      default:
        return isPositive ? Colors.green : Colors.red;
    }
  }
}
