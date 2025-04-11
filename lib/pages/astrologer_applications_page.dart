import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AstrologerApplicationsPage extends StatefulWidget {
  const AstrologerApplicationsPage({super.key});

  @override
  State<AstrologerApplicationsPage> createState() =>
      _AstrologerApplicationsPageState();
}

class _AstrologerApplicationsPageState
    extends State<AstrologerApplicationsPage> {
  List<UserModel> _applications = [];
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
      bool isAdmin = await AuthService.isCurrentUserAdmin();

      setState(() {
        _isAdmin = isAdmin;
      });

      if (isAdmin) {
        _fetchApplications();
      } else {
        setState(() {
          _statusMessage = 'ليس لديك صلاحية الوصول إلى هذه الصفحة';
        });
      }
    } catch (e) {
      setState(() {
        _isAdmin = false;
        _statusMessage = 'حدث خطأ أثناء التحقق من صلاحيات المسؤول';
      });
    }
  }

  Future<void> _fetchApplications() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final applications = await AuthService.getAstrologerApplications();
      setState(() {
        _applications = applications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء جلب طلبات الفلكيين: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateApplicationStatus(String userId, String status) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.getCurrentUser();
      if (currentUser == null) {
        setState(() {
          _statusMessage = 'يجب تسجيل الدخول أولاً';
          _isLoading = false;
        });
        return;
      }

      final result = await AuthService.updateAstrologerStatus(
        userId,
        status,
        currentUser.uid,
      );
      if (result) {
        setState(() {
          _statusMessage = 'تم تحديث حالة الطلب بنجاح';
        });
        _fetchApplications(); // Refresh the list
      } else {
        setState(() {
          _statusMessage = 'فشل في تحديث حالة الطلب';
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
        appBar: AppBar(title: const Text('طلبات الفلكيين')),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchApplications,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _applications.isEmpty
              ? const Center(child: Text('لا توجد طلبات فلكيين معلقة'))
              : Column(
                  children: [
                    if (_statusMessage.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _statusMessage.contains('بنجاح')
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _statusMessage.contains('بنجاح')
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                    Expanded(
                      child: ListView.builder(
                        itemCount: _applications.length,
                        itemBuilder: (context, index) {
                          final application = _applications[index];
                          return Card(
                            margin: const EdgeInsets.all(8.0),
                            child: ExpansionTile(
                              title: Text(
                                '${application.firstName ?? ''} ${application.lastName ?? ''}'
                                        .trim()
                                        .isNotEmpty
                                    ? '${application.firstName ?? ''} ${application.lastName ?? ''}'
                                    : application.email,
                              ),
                              subtitle: Text(
                                'البريد الإلكتروني: ${application.email}',
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'نبذة عن الفلكي:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        application.aboutMe ??
                                            'لا توجد معلومات',
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'الخدمات المقدمة:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (application.services != null &&
                                          application.services!.isNotEmpty)
                                        Wrap(
                                          spacing: 8.0,
                                          children: application.services!.map((
                                            service,
                                          ) {
                                            return Chip(label: Text(service));
                                          }).toList(),
                                        )
                                      else
                                        const Text('لا توجد خدمات محددة'),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.check),
                                            label: const Text('قبول'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                _updateApplicationStatus(
                                              application.id,
                                              'approved',
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            icon: const Icon(Icons.close),
                                            label: const Text('رفض'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                _updateApplicationStatus(
                                              application.id,
                                              'rejected',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
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
