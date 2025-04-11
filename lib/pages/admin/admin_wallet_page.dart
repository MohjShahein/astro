import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/wallet_service.dart';

class AdminWalletPage extends StatefulWidget {
  const AdminWalletPage({super.key});

  @override
  State<AdminWalletPage> createState() => _AdminWalletPageState();
}

class _AdminWalletPageState extends State<AdminWalletPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  bool _isSearching = false;
  UserModel? _selectedUser;
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _adminId = FirebaseAuth.instance.currentUser?.uid;
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await AuthService.getAllUsers(limit: 100);
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar('خطأ في تحميل قائمة المستخدمين: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredUsers = _users;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await AuthService.searchUsers(query);
      setState(() {
        _filteredUsers = results;
        _isSearching = false;
      });
    } catch (e) {
      _showErrorSnackBar('خطأ في البحث: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _selectUser(UserModel user) {
    setState(() {
      _selectedUser = user;
    });
    _showAddFundsDialog(user);
  }

  Future<void> _addFundsToUser(
      UserModel user, double amount, String reason) async {
    if (_adminId == null) {
      _showErrorSnackBar('لم يتم تسجيل الدخول كمشرف');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await WalletService.addFundsByAdmin(
        user.id,
        amount,
        _adminId!,
        reason: reason,
      );

      setState(() {
        _isLoading = false;
      });

      _showSuccessSnackBar('تم إضافة $amount كوينز لـ ${user.fullName} بنجاح');
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('خطأ في إضافة الرصيد: $e');
    }
  }

  void _showAddFundsDialog(UserModel user) {
    _amountController.clear();
    _reasonController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2A),
        title: Text(
          'إضافة رصيد لـ ${user.fullName}',
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.right,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.right,
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
                  suffixStyle: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'سبب الإضافة (اختياري)',
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
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_amountController.text.isEmpty) {
                _showErrorSnackBar('الرجاء إدخال المبلغ');
                return;
              }

              double? amount;
              try {
                amount = double.parse(_amountController.text);
              } catch (e) {
                _showErrorSnackBar('الرجاء إدخال مبلغ صحيح');
                return;
              }

              if (amount <= 0) {
                _showErrorSnackBar('المبلغ يجب أن يكون أكبر من صفر');
                return;
              }

              Navigator.pop(context);
              _addFundsToUser(user, amount, _reasonController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('إضافة الرصيد'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191923),
        title:
            const Text('إدارة المحافظ', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'بحث عن مستخدم...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: const Color(0xFF1E1E2A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                _searchUsers('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        _searchUsers('');
                      } else if (value.length >= 3) {
                        _searchUsers(value);
                      }
                    },
                  ),
                ),

                // Users List
                Expanded(
                  child: _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredUsers.isEmpty
                          ? const Center(
                              child: Text(
                                'لا يوجد مستخدمين',
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                return Card(
                                  color: const Color(0xFF1E1E2A),
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                    horizontal: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.shade800,
                                      child: Text(
                                        user.fullName.isNotEmpty
                                            ? user.fullName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    title: Text(
                                      user.fullName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Text(
                                      user.email,
                                      style: const TextStyle(
                                          color: Colors.white70),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.add_circle,
                                        color: Colors.green,
                                      ),
                                      onPressed: () => _selectUser(user),
                                    ),
                                    onTap: () => _selectUser(user),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
