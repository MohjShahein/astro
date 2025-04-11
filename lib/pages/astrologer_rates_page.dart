import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';

class AstrologerRatesPage extends StatefulWidget {
  const AstrologerRatesPage({super.key});

  @override
  State<AstrologerRatesPage> createState() => _AstrologerRatesPageState();
}

class _AstrologerRatesPageState extends State<AstrologerRatesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _defaultTextRateController =
      TextEditingController();
  final TextEditingController _defaultAudioRateController =
      TextEditingController();
  final TextEditingController _defaultVideoRateController =
      TextEditingController();

  bool _defaultIsFree = false;
  bool _astrologerIsFree = false;

  List<UserModel> _astrologers = [];
  bool _isLoading = true;
  String _statusMessage = '';
  bool _isAdmin = false;
  UserModel? _selectedAstrologer;

  // Controllers for individual astrologer rates
  final TextEditingController _astrologerTextRateController =
      TextEditingController();
  final TextEditingController _astrologerAudioRateController =
      TextEditingController();
  final TextEditingController _astrologerVideoRateController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  @override
  void dispose() {
    _defaultTextRateController.dispose();
    _defaultAudioRateController.dispose();
    _defaultVideoRateController.dispose();
    _astrologerTextRateController.dispose();
    _astrologerAudioRateController.dispose();
    _astrologerVideoRateController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    try {
      bool isAdmin = await AuthService.isCurrentUserAdmin();

      setState(() {
        _isAdmin = isAdmin;
      });

      if (isAdmin) {
        await _loadDefaultRates();
        await _fetchAstrologers();
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

  Future<void> _loadDefaultRates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print("محاولة تحميل الأسعار الافتراضية...");
      DocumentSnapshot doc =
          await _firestore.collection('default_rates').doc('default').get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print("تم العثور على الأسعار الافتراضية: $data");
        setState(() {
          _defaultTextRateController.text = (data['text_rate'] ?? 1).toString();
          _defaultAudioRateController.text =
              (data['audio_rate'] ?? 1.5).toString();
          _defaultVideoRateController.text =
              (data['video_rate'] ?? 2).toString();
          _defaultIsFree = data['is_free'] ?? false;
        });
      } else {
        print("لم يتم العثور على الأسعار الافتراضية، استخدام قيم افتراضية");
        // Set default values if not exists
        setState(() {
          _defaultTextRateController.text = '1';
          _defaultAudioRateController.text = '1.5';
          _defaultVideoRateController.text = '2';
          _defaultIsFree = false;
        });
      }
    } catch (e) {
      print("خطأ في تحميل الأسعار الافتراضية: $e");
      setState(() {
        _statusMessage =
            'حدث خطأ أثناء تحميل الأسعار الافتراضية: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAstrologers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final QuerySnapshot snapshot =
          await _firestore
              .collection('users')
              .where('user_type', isEqualTo: 'astrologer')
              .where('astrologer_status', isEqualTo: 'approved')
              .get();

      final List<UserModel> astrologers = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        astrologers.add(UserModel.fromMap(doc.id, data));
      }

      setState(() {
        _astrologers = astrologers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'حدث خطأ أثناء جلب المنجمين: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDefaultRates() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // التحقق من القيم السالبة
      double textRate = double.tryParse(_defaultTextRateController.text) ?? 0;
      double audioRate = double.tryParse(_defaultAudioRateController.text) ?? 0;
      double videoRate = double.tryParse(_defaultVideoRateController.text) ?? 0;

      if (textRate < 0 || audioRate < 0 || videoRate < 0) {
        throw 'لا يمكن أن تكون الأسعار سالبة';
      }

      // طباعة القيم للتشخيص
      print("محاولة حفظ الأسعار الافتراضية...");
      print("النصية: $textRate");
      print("الصوتية: $audioRate");
      print("الفيديو: $videoRate");
      print("مجاني: $_defaultIsFree");

      await ChatService.setDefaultRates(
        textRate,
        audioRate,
        videoRate,
        isFree: _defaultIsFree,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الأسعار الافتراضية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("خطأ في حفظ الأسعار الافتراضية: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حفظ الأسعار: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAstrologerRates(String astrologerId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print("محاولة تحميل أسعار المنجم $astrologerId ...");
      DocumentSnapshot doc =
          await _firestore
              .collection('astrologer_rates')
              .doc(astrologerId)
              .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print("تم العثور على أسعار المنجم: $data");
        setState(() {
          _astrologerTextRateController.text =
              (data['text_rate'] ?? 1).toString();
          _astrologerAudioRateController.text =
              (data['audio_rate'] ?? 1.5).toString();
          _astrologerVideoRateController.text =
              (data['video_rate'] ?? 2).toString();
          _astrologerIsFree = data['is_free'] ?? false;
        });
      } else {
        print("لم يتم العثور على أسعار المنجم، استخدام الأسعار الافتراضية");
        // Use default rates if not exists
        final defaultRates = await ChatService.getDefaultRates();
        print("الأسعار الافتراضية: $defaultRates");
        setState(() {
          _astrologerTextRateController.text =
              defaultRates['text_rate'].toString();
          _astrologerAudioRateController.text =
              defaultRates['audio_rate'].toString();
          _astrologerVideoRateController.text =
              defaultRates['video_rate'].toString();
          _astrologerIsFree = defaultRates['is_free'] ?? false;
        });
      }
    } catch (e) {
      print("خطأ في تحميل أسعار المنجم: $e");
      setState(() {
        _statusMessage = 'حدث خطأ أثناء تحميل أسعار المنجم: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAstrologerRates() async {
    if (!_formKey.currentState!.validate() || _selectedAstrologer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار منجم أولاً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      // التحقق من القيم السالبة
      double textRate =
          double.tryParse(_astrologerTextRateController.text) ?? 0;
      double audioRate =
          double.tryParse(_astrologerAudioRateController.text) ?? 0;
      double videoRate =
          double.tryParse(_astrologerVideoRateController.text) ?? 0;

      if (textRate < 0 || audioRate < 0 || videoRate < 0) {
        throw 'لا يمكن أن تكون الأسعار سالبة';
      }

      // طباعة القيم للتشخيص
      print("محاولة حفظ أسعار المنجم ${_selectedAstrologer!.id}...");
      print("النصية: $textRate");
      print("الصوتية: $audioRate");
      print("الفيديو: $videoRate");
      print("مجاني: $_astrologerIsFree");

      await ChatService.setAstrologerRates(
        _selectedAstrologer!.id,
        textRate,
        audioRate,
        videoRate,
        isFree: _astrologerIsFree,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ أسعار المنجم بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print("خطأ في حفظ أسعار المنجم: $e");
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في حفظ الأسعار: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleDefaultFreeToggle(bool value) {
    setState(() {
      _defaultIsFree = value;
      if (value) {
        // إذا تم تفعيل الجلسات المجانية، تعيين جميع الأسعار إلى صفر
        _defaultTextRateController.text = '0';
        _defaultAudioRateController.text = '0';
        _defaultVideoRateController.text = '0';
      } else {
        // إذا تم إلغاء تفعيل الجلسات المجانية، إعادة الأسعار إلى القيم الافتراضية
        _loadDefaultRates();
      }
    });
  }

  void _handleAstrologerFreeToggle(bool value) {
    setState(() {
      _astrologerIsFree = value;
      if (value) {
        // إذا تم تفعيل الجلسات المجانية، تعيين جميع الأسعار إلى صفر
        _astrologerTextRateController.text = '0';
        _astrologerAudioRateController.text = '0';
        _astrologerVideoRateController.text = '0';
      } else if (_selectedAstrologer != null) {
        // إذا تم إلغاء تفعيل الجلسات المجانية، إعادة تحميل أسعار المنجم
        _loadAstrologerRates(_selectedAstrologer!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('إدارة أسعار المنجمين')),
        body: const Center(
          child: Text('ليس لديك صلاحية الوصول إلى هذه الصفحة'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الأسعار'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // إعادة تحميل البيانات
              _loadDefaultRates();
              if (_selectedAstrologer != null) {
                _loadAstrologerRates(_selectedAstrologer!.id);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () async {
              // التحقق من بيانات Firestore
              await ChatService.verifyFirestoreData();

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تم التحقق من البيانات، راجع السجلات للمزيد من المعلومات',
                  ),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Default rates section
                      const Text(
                        'الأسعار الافتراضية للمنجمين',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'هذه الأسعار ستكون افتراضية لجميع المنجمين الجدد',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('جلسات مجانية'),
                        subtitle: const Text(
                          'تمكين هذا الخيار لتقديم جلسات مجانية',
                        ),
                        value: _defaultIsFree,
                        onChanged: _handleDefaultFreeToggle,
                      ),
                      const SizedBox(height: 20),

                      // Default text rate
                      _buildRateField(
                        'سعر الدردشة النصية الافتراضي',
                        'أدخل السعر لكل دقيقة',
                        _defaultTextRateController,
                        Icons.chat_bubble_outline,
                      ),
                      const SizedBox(height: 16),

                      // Default audio rate
                      _buildRateField(
                        'سعر المكالمة الصوتية الافتراضي',
                        'أدخل السعر لكل دقيقة',
                        _defaultAudioRateController,
                        Icons.phone_outlined,
                      ),
                      const SizedBox(height: 16),

                      // Default video rate
                      _buildRateField(
                        'سعر مكالمة الفيديو الافتراضي',
                        'أدخل السعر لكل دقيقة',
                        _defaultVideoRateController,
                        Icons.videocam_outlined,
                      ),
                      const SizedBox(height: 24),

                      // Save default rates button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveDefaultRates,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'حفظ الأسعار الافتراضية',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                      const Divider(),
                      const SizedBox(height: 20),

                      // Individual astrologer rates section
                      const Text(
                        'تعيين أسعار منجم محدد',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('جلسات مجانية'),
                        subtitle: const Text(
                          'تمكين هذا الخيار لتقديم جلسات مجانية',
                        ),
                        value: _astrologerIsFree,
                        onChanged: _handleAstrologerFreeToggle,
                      ),
                      const SizedBox(height: 20),

                      // Astrologer dropdown
                      DropdownButtonFormField<UserModel>(
                        decoration: const InputDecoration(
                          labelText: 'اختر المنجم',
                          border: OutlineInputBorder(),
                        ),
                        hint: const Text('اختر منجم'),
                        value: _selectedAstrologer,
                        items:
                            _astrologers.map((UserModel astrologer) {
                              return DropdownMenuItem<UserModel>(
                                value: astrologer,
                                child: Text(
                                  '${astrologer.firstName} ${astrologer.lastName}',
                                ),
                              );
                            }).toList(),
                        onChanged: (UserModel? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedAstrologer = newValue;
                            });
                            _loadAstrologerRates(newValue.id);
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      if (_selectedAstrologer != null) ...[
                        // Astrologer text rate
                        _buildRateField(
                          'سعر الدردشة النصية',
                          'أدخل السعر لكل دقيقة',
                          _astrologerTextRateController,
                          Icons.chat_bubble_outline,
                        ),
                        const SizedBox(height: 16),

                        // Astrologer audio rate
                        _buildRateField(
                          'سعر المكالمة الصوتية',
                          'أدخل السعر لكل دقيقة',
                          _astrologerAudioRateController,
                          Icons.phone_outlined,
                        ),
                        const SizedBox(height: 16),

                        // Astrologer video rate
                        _buildRateField(
                          'سعر مكالمة الفيديو',
                          'أدخل السعر لكل دقيقة',
                          _astrologerVideoRateController,
                          Icons.videocam_outlined,
                        ),
                        const SizedBox(height: 24),

                        // Save astrologer rates button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _saveAstrologerRates,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'حفظ أسعار المنجم',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],

                      if (_statusMessage.isNotEmpty) ...[
                        const SizedBox(height: 24),
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
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildRateField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixText: '/ دقيقة',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'الرجاء إدخال قيمة';
            }
            try {
              double.parse(value);
              return null;
            } catch (e) {
              return 'الرجاء إدخال رقم صحيح';
            }
          },
        ),
      ],
    );
  }
}
