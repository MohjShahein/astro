import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AstrologerApplicationPage extends StatefulWidget {
  final String userId;

  const AstrologerApplicationPage({super.key, required this.userId});

  @override
  State<AstrologerApplicationPage> createState() =>
      _AstrologerApplicationPageState();
}

class _AstrologerApplicationPageState extends State<AstrologerApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _aboutMeController = TextEditingController();
  final List<String> _selectedServices = [];
  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _userData;

  final List<String> _availableServices = [
    'قراءة الطالع',
    'قراءة الكف',
    'تفسير الأحلام',
    'استشارات روحانية',
    'توقعات مستقبلية',
    'تحليل الشخصية',
    'قراءة الأبراج اليومية',
    'تحليل التوافق بين الأبراج',
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await AuthService.getUserData(widget.userId);
      setState(() {
        _userData = userData;
        if (userData != null && userData.aboutMe != null) {
          _aboutMeController.text = userData.aboutMe!;
        }
        if (userData != null && userData.services != null) {
          _selectedServices.addAll(userData.services!);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء تحميل بيانات المستخدم: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedServices.isEmpty) {
      setState(() {
        _errorMessage = 'يرجى اختيار خدمة واحدة على الأقل';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService.applyForAstrologer(
        widget.userId,
        _aboutMeController.text.trim(),
        _selectedServices,
      );

      if (result) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تم تقديم طلبك بنجاح، سيتم مراجعته قريبًا')),
          );
          Navigator.of(context).pop();
        }
      } else {
        setState(() {
          _errorMessage = 'فشل في تقديم الطلب، يرجى المحاولة مرة أخرى';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _aboutMeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // إذا كان المستخدم بالفعل فلكي وحالته معلقة أو مرفوضة
    if (_userData != null && _userData!.userType == 'astrologer') {
      if (_userData!.astrologerStatus == 'pending') {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'طلبك قيد المراجعة حاليًا. سيتم إعلامك بمجرد اتخاذ قرار.',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      } else if (_userData!.astrologerStatus == 'rejected') {
        return Scaffold(
          appBar: AppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'تم رفض طلبك السابق. يمكنك تحديث معلوماتك وإعادة التقديم.',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // إعادة تحميل النموذج للتقديم مرة أخرى
                      _loadUserData();
                    },
                    child: const Text('إعادة التقديم'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'للانضمام كفلكي في التطبيق، يرجى تقديم المعلومات التالية:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _aboutMeController,
                      decoration: const InputDecoration(
                        labelText: 'نبذة عني',
                        hintText: 'اكتب نبذة عن خبرتك ومؤهلاتك في مجال التنجيم',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'يرجى كتابة نبذة عنك';
                        }
                        if (value.length < 50) {
                          return 'يجب أن تكون النبذة 50 حرفًا على الأقل';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'الخدمات التي تقدمها:',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _availableServices.map((service) {
                        final isSelected = _selectedServices.contains(service);
                        return FilterChip(
                          label: Text(service),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedServices.add(service);
                              } else {
                                _selectedServices.remove(service);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitApplication,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('تقديم الطلب'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
