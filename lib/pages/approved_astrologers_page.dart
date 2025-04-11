import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'set_rates_page.dart';

class ApprovedAstrologersPage extends StatefulWidget {
  const ApprovedAstrologersPage({super.key});

  @override
  State<ApprovedAstrologersPage> createState() =>
      _ApprovedAstrologersPageState();
}

class _ApprovedAstrologersPageState extends State<ApprovedAstrologersPage> {
  final TextEditingController _astrologerIdController = TextEditingController();
  List<UserModel> _approvedAstrologers = [];
  bool _isLoading = true;
  String _statusMessage = '';
  bool _isAdmin = false;
  bool _isAddingAstrologer = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      print('_checkAdminStatus: Checking admin status');
      bool isAdmin = await AuthService.isCurrentUserAdmin();

      setState(() {
        _isAdmin = isAdmin;
      });

      if (isAdmin) {
        print('_checkAdminStatus: Admin status result: $isAdmin');
        print(
          '_checkAdminStatus: User is admin, fetching approved astrologers',
        );
        _fetchApprovedAstrologers();
      } else {
        setState(() {
          _statusMessage = 'ليس لديك صلاحية الوصول إلى هذه الصفحة';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _statusMessage = 'حدث خطأ أثناء التحقق من صلاحيات المسؤول';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchApprovedAstrologers() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      print('_fetchApprovedAstrologers: Fetching approved astrologers');
      final approvedAstrologers = await AuthService.getApprovedAstrologers();
      print(
        '_fetchApprovedAstrologers: Fetched ${approvedAstrologers.length} approved astrologers',
      );
      setState(() {
        _approvedAstrologers = approvedAstrologers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage =
            'حدث خطأ أثناء جلب المنجمين المعتمدين: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveAstrologer() async {
    final String astrologerId = _astrologerIdController.text.trim();
    final currentUser = AuthService.getCurrentUser();
    if (currentUser == null) {
      setState(() {
        _statusMessage = 'يجب تسجيل الدخول أولاً';
      });
      return;
    }

    if (astrologerId.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال معرف المنجم';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // التحقق من وجود المستخدم
      final userData = await AuthService.getUserData(astrologerId);

      if (userData == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'المستخدم غير موجود';
        });
        return;
      }

      // التحقق إذا كان المستخدم منجم بالفعل
      if (userData.userType != 'astrologer') {
        // تحديث نوع المستخدم إلى منجم أولاً
        await AuthService.updateUserType(astrologerId, 'astrologer');
      }

      // اعتماد المنجم
      await AuthService.updateAstrologerStatus(
        astrologerId,
        'approved',
        currentUser.uid,
      );

      setState(() {
        _isLoading = false;
        _statusMessage = 'تم اعتماد المنجم بنجاح';
        _astrologerIdController.clear();
        _isAddingAstrologer = false;
      });

      // إعادة تحميل القائمة
      _fetchApprovedAstrologers();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'خطأ: ${e.toString()}';
      });
    }
  }

  Future<void> _revokeAstrologer(String astrologerId) async {
    final currentUser = AuthService.getCurrentUser();
    if (currentUser == null) {
      setState(() {
        _statusMessage = 'يجب تسجيل الدخول أولاً';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // تحديث حالة المنجم في جدول المستخدمين
      await AuthService.updateAstrologerStatus(
        astrologerId,
        'rejected',
        currentUser.uid,
      );

      setState(() {
        _isLoading = false;
        _statusMessage = 'تم إلغاء اعتماد المنجم بنجاح';
      });

      // إعادة تحميل القائمة
      _fetchApprovedAstrologers();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'خطأ: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _astrologerIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('المنجمون المعتمدون')),
        body: Center(
          child: Text(
            _statusMessage.isEmpty
                ? 'ليس لديك صلاحية الوصول إلى هذه الصفحة'
                : _statusMessage,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنجمون المعتمدون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchApprovedAstrologers,
            tooltip: 'تحديث',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _isAddingAstrologer = true;
                _statusMessage = '';
              });
            },
            tooltip: 'إضافة منجم معتمد',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (_isAddingAstrologer) ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إضافة منجم معتمد',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _astrologerIdController,
                            decoration: const InputDecoration(
                              labelText: 'معرف المنجم',
                              hintText: 'أدخل معرف المنجم الذي تريد اعتماده',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isAddingAstrologer = false;
                                    _astrologerIdController.clear();
                                    _statusMessage = '';
                                  });
                                },
                                child: const Text('إلغاء'),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: _approveAstrologer,
                                child: const Text('إضافة'),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                        ],
                      ),
                    ),
                  ],
                  if (_statusMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color:
                            _statusMessage.contains('بنجاح')
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color:
                              _statusMessage.contains('بنجاح')
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                  Expanded(
                    child:
                        _approvedAstrologers.isEmpty
                            ? const Center(
                              child: Text('لا يوجد منجمون معتمدون'),
                            )
                            : ListView.builder(
                              itemCount: _approvedAstrologers.length,
                              itemBuilder: (context, index) {
                                final astrologer = _approvedAstrologers[index];
                                return Card(
                                  margin: const EdgeInsets.all(8.0),
                                  child: ListTile(
                                    leading:
                                        astrologer.profileImageUrl != null
                                            ? CircleAvatar(
                                              backgroundImage: NetworkImage(
                                                astrologer.profileImageUrl!,
                                              ),
                                            )
                                            : const CircleAvatar(
                                              child: Icon(Icons.person),
                                            ),
                                    title: Text(
                                      '${astrologer.firstName ?? ''} ${astrologer.lastName ?? ''}'
                                              .trim()
                                              .isNotEmpty
                                          ? '${astrologer.firstName ?? ''} ${astrologer.lastName ?? ''}'
                                          : astrologer.email,
                                    ),
                                    subtitle: Text(
                                      'البريد الإلكتروني: ${astrologer.email}',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () => _showRevokeConfirmationDialog(
                                            astrologer,
                                          ),
                                    ),
                                    onTap:
                                        () =>
                                            _showAstrologerDetails(astrologer),
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }

  void _showRevokeConfirmationDialog(UserModel astrologer) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('إلغاء اعتماد المنجم'),
            content: Text(
              'هل أنت متأكد من إلغاء اعتماد المنجم ${astrologer.firstName ?? ''} ${astrologer.lastName ?? ''}؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => SetRatesPage(currentUser: astrologer),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('تعيين الأسعار'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _revokeAstrologer(astrologer.id);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('إلغاء الاعتماد'),
              ),
            ],
          ),
    );
  }

  void _showAstrologerDetails(UserModel astrologer) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              '${astrologer.firstName ?? ''} ${astrologer.lastName ?? ''}',
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (astrologer.profileImageUrl != null) ...[
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(
                          astrologer.profileImageUrl!,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('البريد الإلكتروني: ${astrologer.email}'),
                  const SizedBox(height: 8),
                  Text('معرف المستخدم: ${astrologer.id}'),
                  const SizedBox(height: 16),
                  const Text(
                    'نبذة عن المنجم:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(astrologer.aboutMe ?? 'لا توجد معلومات'),
                  const SizedBox(height: 16),
                  const Text(
                    'الخدمات المقدمة:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (astrologer.services != null &&
                      astrologer.services!.isNotEmpty)
                    Wrap(
                      spacing: 8.0,
                      children:
                          astrologer.services!.map((service) {
                            return Chip(label: Text(service));
                          }).toList(),
                    )
                  else
                    const Text('لا توجد خدمات محددة'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => SetRatesPage(currentUser: astrologer),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('تعيين الأسعار'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showRevokeConfirmationDialog(astrologer);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('إلغاء الاعتماد'),
              ),
            ],
          ),
    );
  }
}
