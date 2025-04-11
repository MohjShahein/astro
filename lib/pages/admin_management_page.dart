import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

class AdminManagementPage extends StatefulWidget {
  const AdminManagementPage({super.key});

  @override
  State<AdminManagementPage> createState() => _AdminManagementPageState();
}

class _AdminManagementPageState extends State<AdminManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _statusMessage = '';
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      print('_checkAdminStatus: Checking admin status');
      bool isAdmin = await AuthService.isCurrentUserAdmin();
      print('_checkAdminStatus: Admin status result: $isAdmin');
      
      setState(() {
        _isAdmin = isAdmin;
      });
      
      if (isAdmin) {
        print('_checkAdminStatus: User is admin, fetching users');
        _fetchUsers();
      } else {
        print('_checkAdminStatus: User is not admin');
        setState(() {
          _statusMessage = 'ليس لديك صلاحية الوصول إلى هذه الصفحة';
        });
      }
    } catch (e) {
      print('Error in _checkAdminStatus: $e');
      setState(() {
        _isAdmin = false;
        _statusMessage = 'حدث خطأ أثناء التحقق من صلاحيات المسؤول';
      });
    }
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _statusMessage = ''; // مسح أي رسائل خطأ سابقة
    });

    try {
      print('_fetchUsers: Fetching users from Firestore');
      final QuerySnapshot snapshot = await _firestore.collection('users').get();
      final List<Map<String, dynamic>> users = [];

      print('_fetchUsers: Processing ${snapshot.docs.length} user documents');
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        users.add({
          'id': doc.id,
          'email': data['email'] ?? '',
          'first_name': data['first_name'] ?? '',
          'last_name': data['last_name'] ?? '',
          'is_admin': data['is_admin'] ?? false,
        });
      }

      setState(() {
        _users = users;
        _isLoading = false;
      });
      print('_fetchUsers: Successfully fetched ${users.length} users');
    } catch (e) {
      print('Error in _fetchUsers: $e');
      setState(() {
        _statusMessage = 'حدث خطأ أثناء جلب المستخدمين: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleAdminStatus(String userId, bool currentStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final bool result = await AuthService.setUserAdminStatus(userId, !currentStatus);
      if (result) {
        setState(() {
          _statusMessage = 'تم تحديث حالة المستخدم بنجاح';
          _isLoading = false; // إعادة تعيين حالة التحميل قبل استدعاء _fetchUsers
        });
        _fetchUsers(); // Refresh the list
      } else {
        setState(() {
          _statusMessage = 'فشل تحديث حالة المستخدم';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المستخدمين'),
        ),
        body: const Center(
          child: Text('ليس لديك صلاحية الوصول إلى هذه الصفحة'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المستخدمين'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_statusMessage.isNotEmpty) ...[                
                  Container(
                    margin: const EdgeInsets.all(16.0),
                    padding: const EdgeInsets.all(12.0),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _statusMessage.contains('بنجاح') ? Colors.green.shade100 : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.contains('بنجاح') ? Colors.green.shade900 : Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                Expanded(
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return ListTile(
                        title: Text('${user['first_name']} ${user['last_name']}'),
                        subtitle: Text(user['email']),
                        trailing: Switch(
                          value: user['is_admin'],
                          onChanged: (value) {
                            _toggleAdminStatus(user['id'], user['is_admin']);
                          },
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