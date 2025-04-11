import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/zodiac_service.dart';
import '../services/open_router_service.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _formKey = GlobalKey<FormState>();
  String _selectedZodiacSign = 'aries';
  final TextEditingController _dailyReadingController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  bool _isLoading = false;
  bool _isGeneratingAI = false;
  bool _isSavingApiKey = false;
  String _statusMessage = '';
  bool _isAdmin = false;
  String _currentReading = '';
  bool _showApiKeyField = false;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _fetchCurrentReading();
    _loadSavedApiKey();
  }

  @override
  void dispose() {
    _dailyReadingController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedApiKey() async {
    if (await AuthService.isCurrentUserAdmin()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String? savedApiKey = await OpenRouterService.loadApiKeyFromDatabase();

        if (savedApiKey != null && savedApiKey.isNotEmpty) {
          setState(() {
            _apiKeyController.text = savedApiKey;
            _statusMessage = 'تم تحميل مفتاح API من قاعدة البيانات';
          });
        }
      } catch (e) {
        setState(() {
          _statusMessage = 'حدث خطأ أثناء تحميل مفتاح API: ${e.toString()}';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveApiKeyToDatabase() async {
    if (_apiKeyController.text.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال مفتاح API أولاً';
      });
      return;
    }

    setState(() {
      _isSavingApiKey = true;
      _statusMessage = 'جاري حفظ مفتاح API في قاعدة البيانات...';
    });

    try {
      bool success =
          await OpenRouterService.saveApiKeyToDatabase(_apiKeyController.text);

      setState(() {
        if (success) {
          _statusMessage = 'تم حفظ مفتاح API في قاعدة البيانات بنجاح';
        } else {
          _statusMessage = 'فشل حفظ مفتاح API، تأكد من صلاحياتك الإدارية';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء حفظ مفتاح API: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isSavingApiKey = false;
      });
    }
  }

  Future<void> _fetchCurrentReading() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String reading = await ZodiacService.getZodiacReading(
        _selectedZodiacSign,
      );
      setState(() {
        _currentReading = reading;
        _statusMessage = 'تم جلب القراءة الحالية بنجاح';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء جلب القراءة الحالية: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    bool isAdmin = await AuthService.isCurrentUserAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  Future<void> _updateDailyReading() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      String result = await ZodiacService.updateZodiacReading(
        _selectedZodiacSign,
        _dailyReadingController.text,
      );

      setState(() {
        _statusMessage = result;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateAIReading() async {
    if (_apiKeyController.text.isEmpty) {
      setState(() {
        _statusMessage = 'يرجى إدخال مفتاح API الخاص بك';
      });
      return;
    }

    setState(() {
      _isGeneratingAI = true;
      _statusMessage =
          'جارِ توليد القراءة اليومية باستخدام الذكاء الاصطناعي...';
    });

    try {
      OpenRouterService.setApiKey(_apiKeyController.text);

      String result = await ZodiacService.generateAndUpdateZodiacReading(
        _selectedZodiacSign,
        _apiKeyController.text,
      );

      setState(() {
        _statusMessage = result;
      });

      if (!result.contains('خطأ') && !result.contains('حدث خطأ')) {
        await _fetchCurrentReading();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء توليد القراءة: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isGeneratingAI = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('لوحة الإدارة')),
        body: const Center(
          child: Text('ليس لديك صلاحية الوصول إلى هذه الصفحة'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة الإدارة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'تحديث القراءات اليومية للأبراج',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'اختر البرج',
                  border: OutlineInputBorder(),
                ),
                value: _selectedZodiacSign,
                items: ZodiacService.getAllZodiacSigns().map((String sign) {
                  return DropdownMenuItem<String>(
                    value: sign,
                    child: Text(_getArabicZodiacName(sign)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedZodiacSign = newValue;
                    });
                    _fetchCurrentReading();
                  }
                },
              ),
              const SizedBox(height: 20),
              if (_currentReading.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12.0),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'القراءة الحالية:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentReading,
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              ExpansionTile(
                title: const Text(
                  'توليد القراءة باستخدام الذكاء الاصطناعي',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                leading: const Icon(Icons.auto_awesome),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _apiKeyController,
                          decoration: InputDecoration(
                            labelText: 'مفتاح API الخاص بـ OpenRouter',
                            border: const OutlineInputBorder(),
                            helperText:
                                'أدخل مفتاح API للوصول إلى خدمة OpenRouter',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showApiKeyField
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showApiKeyField = !_showApiKeyField;
                                });
                              },
                            ),
                          ),
                          obscureText: !_showApiKeyField,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.save),
                                label: _isSavingApiKey
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('حفظ مفتاح API'),
                                onPressed: _isSavingApiKey
                                    ? null
                                    : _saveApiKeyToDatabase,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'ملاحظة: سيتم استخدام الذكاء الاصطناعي لإنشاء قراءة جديدة للبرج المحدد استنادًا إلى خبرات علم التنجيم.',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.psychology),
                            label: _isGeneratingAI
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('جارِ التوليد...'),
                                    ],
                                  )
                                : const Text('توليد قراءة جديدة'),
                            onPressed:
                                _isGeneratingAI ? null : _generateAIReading,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              const Text(
                'أو أدخل القراءة اليومية يدويًا:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dailyReadingController,
                decoration: const InputDecoration(
                  labelText: 'القراءة اليومية',
                  border: OutlineInputBorder(),
                ),
                maxLines: 10,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال القراءة اليومية';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateDailyReading,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text('تحديث القراءة اليومية'),
                  ),
                ),
              ),
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 20),
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
            ],
          ),
        ),
      ),
    );
  }

  String _getArabicZodiacName(String englishName) {
    switch (englishName) {
      case 'aries':
        return 'الحمل';
      case 'taurus':
        return 'الثور';
      case 'gemini':
        return 'الجوزاء';
      case 'cancer':
        return 'السرطان';
      case 'leo':
        return 'الأسد';
      case 'virgo':
        return 'العذراء';
      case 'libra':
        return 'الميزان';
      case 'scorpio':
        return 'العقرب';
      case 'sagittarius':
        return 'القوس';
      case 'capricorn':
        return 'الجدي';
      case 'aquarius':
        return 'الدلو';
      case 'pisces':
        return 'الحوت';
      default:
        return englishName;
    }
  }
}
