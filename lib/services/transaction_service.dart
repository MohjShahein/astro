import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new transaction record
  static Future<void> addTransaction(String userId, double amount, String type) async {
    await _firestore.collection('transactions').add({
      'user_id': userId,
      'amount': amount,
      'transaction_type': type, // deposit, withdrawal, payment, etc.
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Retrieves all transactions for a specific user
  static Stream<QuerySnapshot> getUserTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Retrieves all transactions for a user without sorting
  static Stream<QuerySnapshot> getTransactions(String userId) {
    return _firestore
        .collection('transactions')
        .where('user_id', isEqualTo: userId)
        .snapshots();
  }

  /// Retrieves transactions for a user within a date range
  static Stream<QuerySnapshot> getTransactionsByDateRange(
      String userId, DateTime startDate, DateTime endDate) {
    return _firestore
        .collection('transactions')
        .where('user_id', isEqualTo: userId)
        .where('created_at', isGreaterThanOrEqualTo: startDate)
        .where('created_at', isLessThanOrEqualTo: endDate)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Calculates total amount for a specific transaction type
  static Future<double> calculateTotalByType(String userId, String type) async {
    QuerySnapshot snapshot = await _firestore
        .collection('transactions')
        .where('user_id', isEqualTo: userId)
        .where('transaction_type', isEqualTo: type)
        .get();

    double total = 0;
    for (var doc in snapshot.docs) {
      total += (doc.data() as Map<String, dynamic>)['amount'] as double;
    }
    return total;
  }
}