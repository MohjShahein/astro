import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/wallet_service.dart';
import '../models/transaction_model.dart';

class WalletPage extends StatefulWidget {
  final String userId;

  const WalletPage({super.key, required this.userId});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  double _walletBalance = 0.0;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalletBalance();
    _synchronizeWallet();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final balance = await WalletService.getWalletBalance(widget.userId);
      setState(() {
        _walletBalance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل رصيد المحفظة: $e')),
        );
      }
    }
  }

  Future<void> _addFunds() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح')),
      );
      return;
    }

    double amount;
    try {
      amount = double.parse(_amountController.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال مبلغ صحيح')),
      );
      return;
    }

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المبلغ يجب أن يكون أكبر من صفر')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await WalletService.addFunds(widget.userId, amount);
      _amountController.clear();
      await _loadWalletBalance();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إضافة $amount كوينز بنجاح')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في إضافة الرصيد: $e')),
        );
      }
    }
  }

  Future<void> _synchronizeWallet() async {
    try {
      // تجنب محاولة مزامنة المحفظة لتجنب أخطاء الصلاحيات
      print('تم تعطيل مزامنة المحفظة مؤقتاً لتجنب أخطاء الصلاحيات');
      // سنكتفي بالقيمة المحلية المخزنة في _walletBalance
    } catch (e) {
      print('خطأ في مزامنة المحفظة: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191923),
        title: const Text('المحفظة', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet Balance Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: const Color(0xFF1E1E2A),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'رصيد المحفظة',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '$_walletBalance كوينز',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Transaction History Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'سجل المعاملات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Expanded section for transaction history
                Expanded(
                  child: _buildTransactionHistory(),
                ),

                // Add Funds Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: const Color(0xFF1E1E2A),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إضافة رصيد',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'أدخل المبلغ',
                              hintStyle: const TextStyle(color: Colors.white54),
                              filled: true,
                              fillColor: Colors.white12,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              suffixText: 'كوينز',
                              suffixStyle:
                                  const TextStyle(color: Colors.white70),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _addFunds,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'إضافة رصيد',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTransactionHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: WalletService.getTransactionHistory(widget.userId),
      builder: (context, snapshot) {
        // عرض مؤشر التحميل أثناء الانتظار
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        // استعداد لتجميع المعاملات من مختلف المصادر
        List<TransactionModel> allTransactions = [];

        // معاملات من الاستعلام الأول (المستخدم كمالك)
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final userTransactions = snapshot.data!.docs.map((doc) {
            return TransactionModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
          }).toList();

          allTransactions.addAll(userTransactions);
        }

        // جمع المعاملات من مصادر أخرى باستخدام FutureBuilder
        return FutureBuilder<List<TransactionModel>>(
          future: _getAllTransactions(),
          builder: (context, transactionsSnapshot) {
            if (transactionsSnapshot.connectionState ==
                ConnectionState.waiting) {
              // إذا كان لدينا بيانات من الاستعلام الأول، نعرضها أثناء تحميل البقية
              if (allTransactions.isNotEmpty) {
                allTransactions
                    .sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return _buildTransactionsList(allTransactions);
              }

              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (transactionsSnapshot.hasError) {
              print('خطأ في جمع المعاملات: ${transactionsSnapshot.error}');
              // إذا كان لدينا بيانات من الاستعلام الأول، نعرضها على الرغم من الخطأ
              if (allTransactions.isNotEmpty) {
                allTransactions
                    .sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return _buildTransactionsList(allTransactions);
              }

              return _buildEmptyTransactionMessage();
            }

            if (transactionsSnapshot.hasData) {
              // دمج المعاملات من جميع المصادر
              allTransactions.addAll(transactionsSnapshot.data!);

              // إزالة المعاملات المكررة
              final ids = <String>{};
              allTransactions
                  .retainWhere((transaction) => ids.add(transaction.id));

              // ترتيب المعاملات محلياً حسب تاريخ الإنشاء
              allTransactions
                  .sort((a, b) => b.createdAt.compareTo(a.createdAt));

              if (allTransactions.isEmpty) {
                return _buildEmptyTransactionMessage();
              }

              return _buildTransactionsList(allTransactions);
            }

            return _buildEmptyTransactionMessage();
          },
        );
      },
    );
  }

  // وظيفة جديدة لجمع المعاملات من مختلف المصادر
  Future<List<TransactionModel>> _getAllTransactions() async {
    final List<TransactionModel> transactions = [];

    try {
      // المعاملات حيث المستخدم هو الطرف الآخر
      final otherPartySnapshot =
          await WalletService.getTransactionsAsOtherParty(widget.userId).first;
      if (otherPartySnapshot.docs.isNotEmpty) {
        final otherPartyTransactions = otherPartySnapshot.docs.map((doc) {
          return TransactionModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          );
        }).toList();

        transactions.addAll(otherPartyTransactions);
      }

      // المعاملات حيث المستخدم هو المنجم
      final astrologerSnapshot =
          await WalletService.getTransactionsAsAstrologer(widget.userId).first;
      if (astrologerSnapshot.docs.isNotEmpty) {
        final astrologerTransactions = astrologerSnapshot.docs.where((doc) {
          // استبعاد المعاملات حيث المستخدم هو المالك أيضًا (ترشيح يدوي)
          final data = doc.data() as Map<String, dynamic>;
          return data['user_id'] != widget.userId;
        }).map((doc) {
          return TransactionModel.fromMap(
            doc.id,
            doc.data() as Map<String, dynamic>,
          );
        }).toList();

        transactions.addAll(astrologerTransactions);
      }

      return transactions;
    } catch (e) {
      print('خطأ في الحصول على المعاملات المتعددة: $e');
      return transactions; // نعيد ما جمعناه حتى الآن
    }
  }

  // دالة لعرض رسالة عند عدم وجود معاملات
  Widget _buildEmptyTransactionMessage() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.white30,
          ),
          SizedBox(height: 16),
          Text(
            'لا توجد معاملات حتى الآن',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'ستظهر معاملاتك هنا مباشرة عند إجراء إيداع أو دفع مقابل جلسة',
              style: TextStyle(color: Colors.white38, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList(List<TransactionModel> transactions) {
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return Card(
          color: const Color(0xFF1E1E2A),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              backgroundColor: transaction.color.withOpacity(0.2),
              child: Icon(
                transaction.icon,
                color: transaction.color,
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    transaction.typeInArabic,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${transaction.amount.abs().toStringAsFixed(1)} كوينز',
                  style: TextStyle(
                    color: transaction.isPositive
                        ? Colors.green[300]
                        : Colors.red[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (transaction.shortDescription != transaction.typeInArabic)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      transaction.shortDescription,
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('yyyy/MM/dd - hh:mm a')
                        .format(transaction.createdAt),
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
            onTap: () => _showTransactionDetails(transaction),
          ),
        );
      },
    );
  }

  void _showTransactionDetails(TransactionModel transaction) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: transaction.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    transaction.icon,
                    color: transaction.color,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  transaction.typeInArabic,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (transaction.shortDescription != transaction.typeInArabic)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      transaction.shortDescription,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '${transaction.formattedAmount} كوينز',
                  style: TextStyle(
                    color: transaction.isPositive
                        ? Colors.green[300]
                        : Colors.red[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              _buildDetailRow('معرف المعاملة:', transaction.id),
              if (transaction.sessionId != null &&
                  transaction.sessionId!.isNotEmpty)
                _buildDetailRow('معرف الجلسة:', transaction.sessionId!),
              _buildDetailRow(
                  'التاريخ والوقت:',
                  DateFormat('yyyy/MM/dd - hh:mm:ss a')
                      .format(transaction.createdAt)),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('إغلاق'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
