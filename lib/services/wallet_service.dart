import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction_model.dart';

class WalletService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, double> _walletBalances = {};

  /// كلاس ذكي لتخزين قيم رصيد المحفظة مؤقتًا
  static final Map<String, _CachedBalance> _cachedBalances = {};

  /// Gets the current wallet balance for a user with smart caching
  static Future<double> getWalletBalance(String userId) async {
    try {
      // تحقق من وجود قيمة مخزنة مؤقتًا حديثة (أقل من 30 ثانية)
      if (_cachedBalances.containsKey(userId)) {
        final cachedBalance = _cachedBalances[userId]!;
        if (cachedBalance.isValid()) {
          return cachedBalance.balance;
        }
      }

      // أولاً نتحقق مما إذا كان للمستخدم وثيقة محفظة
      DocumentSnapshot walletDoc =
          await _firestore.collection('wallets').doc(userId).get();

      double balance = 0.0;
      if (walletDoc.exists && walletDoc.data() != null) {
        // استخدام الرصيد المخزن في وثيقة المحفظة
        Map<String, dynamic> data = walletDoc.data() as Map<String, dynamic>;

        print('بيانات المحفظة للمستخدم $userId: ${data.toString()}');

        if (data.containsKey('balance')) {
          final dynamic rawBalance = data['balance'];
          print(
              'الرصيد الخام من قاعدة البيانات: $rawBalance (النوع: ${rawBalance.runtimeType})');

          // تحويل الرصيد إلى double بغض النظر عن نوعه
          if (rawBalance is num) {
            balance = rawBalance.toDouble();
          } else if (rawBalance is String) {
            // محاولة تحويل String إلى double
            try {
              balance = double.parse(rawBalance);
            } catch (e) {
              print('خطأ في تحويل النص إلى رقم: $e');
            }
          } else {
            print('نوع غير معروف للرصيد: ${rawBalance.runtimeType}');
          }
        } else {
          print('لا يوجد حقل رصيد في وثيقة المحفظة');
        }

        print('تم تحويل الرصيد إلى: $balance');
      } else {
        // إذا لم تكن هناك محفظة، ننشئ واحدة بقيمة صفر
        try {
          await _firestore.collection('wallets').doc(userId).set({
            'balance': 0.0,
            'created_at': FieldValue.serverTimestamp(),
            'last_updated': FieldValue.serverTimestamp(),
            'user_id': userId,
          });
          print('تم إنشاء محفظة جديدة للمستخدم $userId');
        } catch (e) {
          print('فشل في إنشاء محفظة جديدة: $e');
          // نستمر في أي حال
        }
      }

      // تخزين القيمة مؤقتًا
      _cachedBalances[userId] = _CachedBalance(balance);
      // تخزين في الذاكرة المحلية أيضًا (للاستخدام بين جلسات)
      _walletBalances[userId] = balance;

      return balance;
    } catch (e) {
      print('خطأ في الحصول على رصيد المحفظة: $e');

      // استخدام القيمة المخزنة محليًا إذا كانت متوفرة
      if (_walletBalances.containsKey(userId)) {
        print('استخدام القيمة المخزنة محليًا: ${_walletBalances[userId]}');
        return _walletBalances[userId]!;
      }

      // قيمة افتراضية في حالة فشل كافة المحاولات
      return 0.0;
    }
  }

  /// تحديث الرصيد المخزن مؤقتًا (يستخدم عند الحاجة لتحديث القيمة دون استعلام)
  static void _updateCachedBalance(String userId, double newBalance) {
    _cachedBalances[userId] = _CachedBalance(newBalance);
    _walletBalances[userId] = newBalance;
  }

  /// Validates if user has sufficient balance for a session
  static Future<bool> validateBalance(
      String userId, double requiredAmount) async {
    return (await getWalletBalance(userId)) >= requiredAmount;
  }

  /// Calculates total amount for a specific transaction type
  static Future<double> _calculateTotalByType(
      String userId, String type) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('transactions')
          .where('user_id', isEqualTo: userId)
          .where('transaction_type', isEqualTo: type)
          .get();

      double total = 0.0;
      for (var doc in snapshot.docs) {
        final dynamic amount = doc.get('amount');
        if (amount is num) {
          total += amount.toDouble();
        }
      }
      return total;
    } catch (e) {
      print('خطأ في حساب مجموع معاملات النوع $type: $e');
      return 0.0;
    }
  }

  /// Adds funds to user's wallet
  static Future<void> addFunds(String userId, double amount) async {
    final batch = _firestore.batch();

    // إنشاء معاملة جديدة
    DocumentReference transactionRef =
        _firestore.collection('transactions').doc();
    batch.set(transactionRef, {
      'user_id': userId,
      'amount': amount,
      'transaction_type': 'deposit',
      'created_at': FieldValue.serverTimestamp(),
      'description': 'إيداع رصيد في المحفظة',
    });

    // تحديث المحفظة
    DocumentReference walletRef = _firestore.collection('wallets').doc(userId);
    DocumentSnapshot walletSnapshot = await walletRef.get();

    if (walletSnapshot.exists && walletSnapshot.data() != null) {
      double currentBalance =
          (walletSnapshot.data() as Map<String, dynamic>)['balance'] ?? 0.0;
      batch.update(walletRef, {
        'balance': currentBalance + amount,
        'last_updated': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(walletRef, {
        'balance': amount,
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Processes a refund for a cancelled session
  static Future<void> processRefund(
    String userId,
    double amount, {
    bool isPartial = false,
    String? sessionId,
    String? sessionTitle,
  }) async {
    final batch = _firestore.batch();

    // إنشاء معاملة جديدة
    DocumentReference transactionRef =
        _firestore.collection('transactions').doc();
    batch.set(transactionRef, {
      'user_id': userId,
      'amount': amount,
      'transaction_type': isPartial ? 'partial_refund' : 'refund',
      'created_at': FieldValue.serverTimestamp(),
      'session_id': sessionId,
      'session_title': sessionTitle,
      'description': isPartial ? 'استرداد جزئي للجلسة' : 'استرداد كامل للجلسة',
    });

    // تحديث المحفظة
    DocumentReference walletRef = _firestore.collection('wallets').doc(userId);
    DocumentSnapshot walletSnapshot = await walletRef.get();

    if (walletSnapshot.exists && walletSnapshot.data() != null) {
      double currentBalance =
          (walletSnapshot.data() as Map<String, dynamic>)['balance'] ?? 0.0;
      batch.update(walletRef, {
        'balance': currentBalance + amount,
        'last_updated': FieldValue.serverTimestamp(),
      });
    } else {
      batch.set(walletRef, {
        'balance': amount,
        'created_at': FieldValue.serverTimestamp(),
        'last_updated': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// الحصول على تاريخ المعاملات للمستخدم
  static Stream<QuerySnapshot> getTransactionHistory(String userId) {
    try {
      print('جاري استعلام المعاملات للمستخدم: $userId');

      // بما أن Firestore لا يدعم الاستعلامات المركبة بـ OR مباشرة،
      // فسنستخدم استعلامًا مبسطًا يبحث عن المستخدم كمالك فقط
      return _firestore
          .collection('transactions')
          .where('user_id', isEqualTo: userId)
          .limit(50)
          .snapshots();

      // ملاحظة: سنعتمد على استدعاء getTransactionsAsOtherParty لاحقًا في WalletPage
      // للحصول على المعاملات التي يكون فيها المستخدم طرفًا آخر
    } catch (e) {
      print('خطأ في استعلام المعاملات: $e');
      // إرجاع استعلام فارغ في حالة الخطأ
      return _firestore
          .collection('transactions')
          .where('user_id', isEqualTo: 'non_existent_id')
          .snapshots();
    }
  }

  /// الحصول على المعاملات حيث المستخدم هو الطرف الآخر
  static Stream<QuerySnapshot> getTransactionsAsOtherParty(String userId) {
    try {
      print('جاري استعلام المعاملات حيث المستخدم هو الطرف آخر: $userId');
      // استعلام عن المعاملات حيث المستخدم هو الطرف الآخر (other_party_id)
      // أو حيث المستخدم هو المنجم (astrologer_id) ولكن ليس المالك (user_id)
      return _firestore
          .collection('transactions')
          .where('other_party_id', isEqualTo: userId)
          .limit(50)
          .snapshots();
    } catch (e) {
      print('خطأ في استعلام المعاملات كطرف آخر: $e');
      // إرجاع استعلام فارغ في حالة الخطأ
      return _firestore
          .collection('transactions')
          .where('other_party_id', isEqualTo: 'non_existent_id')
          .snapshots();
    }
  }

  /// الحصول على المعاملات حيث المستخدم هو المنجم
  static Stream<QuerySnapshot> getTransactionsAsAstrologer(String userId) {
    try {
      print('جاري استعلام المعاملات حيث المستخدم هو المنجم: $userId');

      // نستخدم استعلامًا بسيطًا بدلاً من الاستعلام المركب لتجنب الحاجة إلى فهرس مخصص
      return _firestore
          .collection('transactions')
          .where('astrologer_id', isEqualTo: userId)
          .limit(50)
          .snapshots();

      // ملاحظة: سنقوم بترشيح النتائج لاحقًا في _getAllTransactions
    } catch (e) {
      print('خطأ في استعلام المعاملات كمنجم: $e');
      // إرجاع استعلام فارغ في حالة الخطأ
      return _firestore
          .collection('transactions')
          .where('astrologer_id', isEqualTo: 'non_existent_id')
          .snapshots();
    }
  }

  /// Gets paginated transaction history
  static Future<List<TransactionModel>> getPaginatedTransactions(
    String userId, {
    DocumentSnapshot? lastDocument,
    int limit = 20,
  }) async {
    try {
      // نقوم باستخدام الاستعلام البسيط هنا
      Query query = _firestore
          .collection('transactions')
          .where('user_id', isEqualTo: userId)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      QuerySnapshot snapshot = await query.get();

      List<TransactionModel> transactions = snapshot.docs.map((doc) {
        return TransactionModel.fromMap(
          doc.id,
          doc.data() as Map<String, dynamic>,
        );
      }).toList();

      // ترتيب المعاملات محليًا حسب تاريخ الإنشاء (من الأحدث للأقدم)
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return transactions;
    } catch (e) {
      print('خطأ في الحصول على المعاملات: $e');
      return [];
    }
  }

  /// Synchronize wallet balance with transactions
  static Future<void> synchronizeWalletBalance(String userId) async {
    try {
      // بدلاً من حساب الرصيد من المعاملات، سنسجل فقط تاريخ المزامنة
      // وسنترك الرصيد كما هو (أو نضع قيمة افتراضية إذا لم تكن هناك محفظة)

      DocumentReference walletRef =
          _firestore.collection('wallets').doc(userId);
      DocumentSnapshot walletSnapshot = await walletRef.get();

      Map<String, dynamic> walletData = {
        'last_synchronized': FieldValue.serverTimestamp(),
      };

      if (!walletSnapshot.exists) {
        // إنشاء محفظة جديدة إذا لم تكن موجودة
        walletData['balance'] = 0.0;
        walletData['created_at'] = FieldValue.serverTimestamp();
      }

      walletData['last_updated'] = FieldValue.serverTimestamp();

      try {
        await walletRef.set(walletData, SetOptions(merge: true));
        print('تم مزامنة محفظة المستخدم: $userId');
      } catch (permissionError) {
        print('خطأ في الصلاحيات أثناء تحديث وثيقة المحفظة: $permissionError');
      }
    } catch (e) {
      print('خطأ في مزامنة رصيد المحفظة: $e');
      rethrow;
    }
  }

  /// إنشاء معاملة مالية مرتبطة بجلسة
  /// يستخدم معاملات الدفعة الواحدة لضمان إتمام العملية بأكملها أو إلغائها
  static Future<bool> createSessionTransaction({
    required String userId,
    required double amount,
    required String transactionType,
    String? sessionId,
    String? sessionTitle,
    String? otherPartyId,
    String? description,
  }) async {
    try {
      // التحقق من صحة المبلغ
      if (amount == 0) {
        throw Exception('المبلغ غير صالح');
      }

      // إنشاء معاملة جديدة
      final transactionRef = _firestore.collection('transactions').doc();
      final walletRef = _firestore.collection('wallets').doc(userId);

      // بدء المعاملة
      await _firestore.runTransaction((transaction) async {
        // الحصول على رصيد المحفظة الحالي
        final walletDoc = await transaction.get(walletRef);
        final currentBalance = walletDoc.exists
            ? (walletDoc.data()!['balance'] as num).toDouble()
            : 0.0;

        // التحقق من الرصيد الكافي للخصم
        if (amount < 0 && currentBalance < -amount) {
          throw Exception('رصيد غير كافٍ');
        }

        // حساب الرصيد الجديد
        final newBalance = currentBalance + amount;

        // إنشاء المعاملة
        final transactionData = {
          'id': transactionRef.id,
          'user_id': userId,
          'amount': amount,
          'type': transactionType,
          'status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
          'session_id': sessionId,
          'session_title': sessionTitle,
          'other_party_id': otherPartyId,
          'description': description ?? 'معاملة جلسة استشارية',
        };

        // تحديث المحفظة
        final walletData = {
          'balance': newBalance,
          'last_transaction_id': transactionRef.id,
          'last_transaction_type': transactionType,
          'last_transaction_amount': amount,
          'last_transaction_status': 'pending',
          'updated_at': FieldValue.serverTimestamp(),
        };

        // حفظ التغييرات
        transaction.set(transactionRef, transactionData);
        transaction.set(walletRef, walletData, SetOptions(merge: true));
      });

      // تحديث حالة المعاملة إلى مكتملة
      await transactionRef.update({
        'status': 'completed',
        'completed_at': FieldValue.serverTimestamp(),
      });

      // تحديث حالة المعاملة في المحفظة
      await walletRef.update({
        'last_transaction_status': 'completed',
      });

      return true;
    } catch (e) {
      print('خطأ في إنشاء المعاملة: $e');
      // تسجيل الخطأ في Firestore
      await _firestore.collection('transaction_errors').add({
        'user_id': userId,
        'amount': amount,
        'type': transactionType,
        'session_id': sessionId,
        'error': e.toString(),
        'created_at': FieldValue.serverTimestamp(),
      });
      return false;
    }
  }

  /// Adds funds to user's wallet by admin
  static Future<void> addFundsByAdmin(
    String userId,
    double amount,
    String adminId, {
    String? reason,
  }) async {
    try {
      final batch = _firestore.batch();

      // إنشاء معاملة جديدة
      DocumentReference transactionRef =
          _firestore.collection('transactions').doc();
      batch.set(transactionRef, {
        'user_id': userId,
        'amount': amount,
        'transaction_type': 'admin_adjustment',
        'created_at': FieldValue.serverTimestamp(),
        'description': reason ?? 'إضافة رصيد بواسطة مشرف',
        'admin_id': adminId,
        'is_admin_transaction': true,
      });

      // تحديث المحفظة
      DocumentReference walletRef =
          _firestore.collection('wallets').doc(userId);
      DocumentSnapshot walletSnapshot = await walletRef.get();

      if (walletSnapshot.exists && walletSnapshot.data() != null) {
        final data = walletSnapshot.data() as Map<String, dynamic>;
        // تحويل الرصيد الحالي إلى double بغض النظر عن نوعه (int أو double)
        double currentBalance = 0.0;
        if (data.containsKey('balance')) {
          if (data['balance'] is int) {
            currentBalance = (data['balance'] as int).toDouble();
          } else if (data['balance'] is double) {
            currentBalance = data['balance'] as double;
          } else if (data['balance'] is num) {
            currentBalance = (data['balance'] as num).toDouble();
          }
        }

        batch.update(walletRef, {
          'balance': currentBalance + amount,
          'last_updated': FieldValue.serverTimestamp(),
          'last_admin_adjustment': FieldValue.serverTimestamp(),
          'last_admin_id': adminId,
        });
      } else {
        batch.set(walletRef, {
          'balance': amount,
          'created_at': FieldValue.serverTimestamp(),
          'last_updated': FieldValue.serverTimestamp(),
          'last_admin_adjustment': FieldValue.serverTimestamp(),
          'last_admin_id': adminId,
        });
      }

      await batch.commit();
      print('تم إضافة $amount كوينز للمستخدم $userId بواسطة المشرف $adminId');

      return;
    } catch (e) {
      print('خطأ في إضافة الرصيد بواسطة المشرف: $e');
      rethrow;
    }
  }
}

/// كلاس لإدارة تخزين الرصيد المؤقت مع التحقق من الصلاحية
class _CachedBalance {
  final double balance;
  final DateTime timestamp;
  // مدة صلاحية التخزين المؤقت (30 ثانية)
  static const Duration _validityDuration = Duration(seconds: 30);

  _CachedBalance(this.balance) : timestamp = DateTime.now();

  bool isValid() {
    return DateTime.now().difference(timestamp) < _validityDuration;
  }
}
