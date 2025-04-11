import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SetRatesPage extends StatefulWidget {
  final UserModel currentUser;

  const SetRatesPage({super.key, required this.currentUser});

  @override
  _SetRatesPageState createState() => _SetRatesPageState();
}

class _SetRatesPageState extends State<SetRatesPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _textRateController = TextEditingController();
  final TextEditingController _audioRateController = TextEditingController();
  final TextEditingController _videoRateController = TextEditingController();
  bool _isLoading = true;
  bool _isFree = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentRates();
  }

  @override
  void dispose() {
    _textRateController.dispose();
    _audioRateController.dispose();
    _videoRateController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentRates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rates = await ChatService.getAstrologerRate(widget.currentUser.id);

      setState(() {
        _isFree = rates['is_free'] ?? false;
        _textRateController.text = rates['text_rate'].toString();
        _audioRateController.text = rates['audio_rate'].toString();
        _videoRateController.text = rates['video_rate'].toString();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading rates: $e');
      setState(() {
        _textRateController.text = '0';
        _audioRateController.text = '0';
        _videoRateController.text = '0';
        _isLoading = false;
      });
    }
  }

  void _handleFreeToggle(bool value) {
    setState(() {
      _isFree = value;
      if (value) {
        // إذا تم تفعيل الجلسات المجانية، تعيين جميع الأسعار إلى صفر
        _textRateController.text = '0';
        _audioRateController.text = '0';
        _videoRateController.text = '0';
      } else {
        // إذا تم إلغاء تفعيل الجلسات المجانية، تعيين أسعار افتراضية
        _textRateController.text = '1';
        _audioRateController.text = '1.5';
        _videoRateController.text = '2';
      }
    });
  }

  Future<void> _saveRates() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        throw 'يجب تسجيل الدخول لحفظ الأسعار';
      }

      // التحقق من القيم السالبة
      double textRate = double.tryParse(_textRateController.text) ?? 0;
      double audioRate = double.tryParse(_audioRateController.text) ?? 0;
      double videoRate = double.tryParse(_videoRateController.text) ?? 0;

      if (textRate < 0 || audioRate < 0 || videoRate < 0) {
        throw 'لا يمكن أن تكون الأسعار سالبة';
      }

      // طباعة معلومات فقط إذا كانت الجلسات مجانية
      if (_isFree) {
        print(
          "الجلسات مجانية، الأسعار المدخلة: text=$textRate, audio=$audioRate, video=$videoRate",
        );
      }

      // طباعة القيم للتشخيص
      print(
        'حفظ الأسعار: text=$textRate, audio=$audioRate, video=$videoRate, isFree=$_isFree',
      );

      // حفظ الأسعار
      await ChatService.setAstrologerRates(
        userId,
        textRate,
        audioRate,
        videoRate,
        isFree: _isFree,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الأسعار بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تعيين أسعار الجلسات'),
        centerTitle: true,
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
                      // Free session toggle
                      SwitchListTile(
                        title: const Text('جلسات مجانية'),
                        subtitle: const Text(
                          'تمكين هذا الخيار لتقديم جلسات مجانية',
                        ),
                        value: _isFree,
                        onChanged: _handleFreeToggle,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'قم بتعيين أسعار الجلسات المختلفة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'يتم احتساب السعر لكل دقيقة من الجلسة. إذا كنت لا ترغب في تقديم نوع معين من الجلسات، اترك السعر 0.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),

                      // Text chat rate
                      _buildRateField(
                        'سعر الدردشة النصية',
                        'أدخل السعر لكل دقيقة',
                        _textRateController,
                        Icons.chat_bubble_outline,
                      ),
                      const SizedBox(height: 16),

                      // Audio call rate
                      _buildRateField(
                        'سعر المكالمة الصوتية',
                        'أدخل السعر لكل دقيقة',
                        _audioRateController,
                        Icons.phone_outlined,
                      ),
                      const SizedBox(height: 16),

                      // Video call rate
                      _buildRateField(
                        'سعر مكالمة الفيديو',
                        'أدخل السعر لكل دقيقة',
                        _videoRateController,
                        Icons.videocam_outlined,
                      ),
                      const SizedBox(height: 32),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveRates,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text(
                            'حفظ الأسعار',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
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
