import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../services/wallet_service.dart';
import '../components/user_profile_image.dart';
import '../models/user_model.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class RequestSessionPage extends StatefulWidget {
  final UserModel currentUser;
  final String astrologerId;
  final String astrologerName;
  final String astrologerImage;
  final double sessionPrice;
  final bool offersFreeSession;

  const RequestSessionPage({
    super.key,
    required this.currentUser,
    required this.astrologerId,
    required this.astrologerName,
    required this.astrologerImage,
    required this.sessionPrice,
    required this.offersFreeSession,
  });

  @override
  State<RequestSessionPage> createState() => _RequestSessionPageState();
}

class _RequestSessionPageState extends State<RequestSessionPage> {
  String _selectedSessionType = 'text';
  bool _isLoading = false;
  Map<String, dynamic>? _astrologerRates;
  double _userBalance = 0.0;
  bool _hasActiveSession = false;
  int _freeSessionsUsed = 0;
  bool _isCheckingFreeSessionLimit = true;
  bool _astrologerOffersFree = false;
  bool _isAdmin = false;
  final bool _isAstrologer = false;
  final bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadAstrologerRates();
    _checkUserStatus();
    _checkFreeSessionsUsed();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      _isAdmin = await AuthService.isCurrentUserAdmin();
      if (mounted) setState(() {});
      print('حالة المشرف: $_isAdmin');
    } catch (e) {
      print('خطأ في التحقق من حالة المشرف: $e');
    }
  }

  Future<void> _checkFreeSessionsUsed() async {
    setState(() {
      _isCheckingFreeSessionLimit = true;
    });

    try {
      final count = await ChatService.getUserFreeSessions(
        widget.currentUser.id,
      );
      print('عدد الجلسات المجانية المستخدمة: $count');

      setState(() {
        _freeSessionsUsed = count;
        _isCheckingFreeSessionLimit = false;
      });
    } catch (e) {
      print('خطأ في التحقق من عدد الجلسات المجانية: $e');
      setState(() {
        _isCheckingFreeSessionLimit = false;
      });
    }
  }

  Future<void> _checkUserStatus() async {
    try {
      // التحقق من وجود جلسة نشطة
      _hasActiveSession = await ChatService.hasActiveSession(
        widget.currentUser.id,
      );

      if (!mounted) return;

      // التحقق من رصيد المحفظة
      _userBalance = await WalletService.getWalletBalance(
        widget.currentUser.id,
      );

      if (!mounted) return;

      setState(() {});
    } catch (e) {
      print('Error checking user status: $e');
    }
  }

  Future<void> _loadAstrologerRates() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rates = await ChatService.getAstrologerRate(widget.astrologerId);
      setState(() {
        _astrologerRates = {
          'text_rate': (rates['text_rate'] is num)
              ? (rates['text_rate'] as num).toDouble()
              : 0.0,
          'audio_rate': (rates['audio_rate'] is num)
              ? (rates['audio_rate'] as num).toDouble()
              : 0.0,
          'video_rate': (rates['video_rate'] is num)
              ? (rates['video_rate'] as num).toDouble()
              : 0.0,
        };
        _astrologerOffersFree = rates['is_free'] ?? false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _astrologerRates = {
          'text_rate': 0.0,
          'audio_rate': 0.0,
          'video_rate': 0.0,
        };
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل الأسعار: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _getCurrentRate() {
    if (_astrologerRates == null) return 0.0;

    switch (_selectedSessionType) {
      case 'text':
        return _astrologerRates!['text_rate'];
      case 'audio':
        return _astrologerRates!['audio_rate'];
      case 'video':
        return _astrologerRates!['video_rate'];
      default:
        return 0.0;
    }
  }

  Future<void> _requestFreeSession() async {
    print('طلب جلسة مجانية: بدء الإجراء');
    if (_hasActiveSession) {
      print('طلب جلسة مجانية: يوجد جلسة نشطة بالفعل');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لديك جلسة نشطة بالفعل. يرجى إنهاء الجلسة الحالية قبل بدء جلسة جديدة.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? createdSessionId;

    try {
      print('طلب جلسة مجانية: التحقق من عدد الجلسات المجانية المستخدمة');
      // إعادة التحقق من العدد الفعلي للجلسات المجانية المستخدمة قبل إنشاء جلسة جديدة
      final actualSessionsUsed = await ChatService.getUserFreeSessions(
        widget.currentUser.id,
      );

      print('عدد الجلسات المجانية الفعلي المستخدمة: $actualSessionsUsed');

      // تعطيل التحقق مؤقتًا للسماح بإنشاء جلسات
      if (false && actualSessionsUsed >= ChatService.FREE_SESSION_LIMIT) {
        print('طلب جلسة مجانية: تم الوصول للحد الأقصى للجلسات المجانية');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لقد وصلت إلى الحد الأقصى للجلسات المجانية اليوم'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
          // تحديث العدد المعروض في واجهة المستخدم
          _freeSessionsUsed = actualSessionsUsed;
        });
        return;
      }

      print('بدء جلسة مجانية مع الفلكي: ${widget.astrologerId}');

      try {
        createdSessionId = await ChatService.createChatSession(
          widget.currentUser.id,
          widget.astrologerId,
          'text', // استخدام دردشة نصية كنوع افتراضي للجلسات المجانية
          isFree: true, // تحديد أن هذه جلسة مجانية
        );

        print('طلب جلسة مجانية: تم إنشاء الجلسة بنجاح: $createdSessionId');
      } catch (sessionError) {
        print('خطأ في إنشاء الجلسة: $sessionError');
        rethrow;
      }

      // محاولة إضافة إشعار ولكن لا نوقف التنفيذ في حالة فشله
      if (createdSessionId != null) {
        try {
          await NotificationService.addNotification(
            widget.currentUser.id,
            'تم إنشاء جلسة مجانية جديدة مع الفلكي ${widget.astrologerName}. المدة: ${ChatService.FREE_SESSION_DURATION} دقيقة',
          );
          print('تم إضافة إشعار للمستخدم بنجاح');
        } catch (notificationError) {
          // فقط تسجيل الخطأ، ولكن نستمر في التنفيذ
          print('خطأ في إضافة إشعار للمستخدم: $notificationError');
        }

        // تحديث عدد الجلسات المجانية المستخدمة بعد الإنشاء بنجاح
        _checkFreeSessionsUsed();
      }

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الجلسة المجانية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('خطأ في إنشاء الجلسة المجانية: $e');
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      // إعادة التحقق من الجلسات المستخدمة في حالة حدوث خطأ
      _checkFreeSessionsUsed();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء الجلسة المجانية: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _requestSession() async {
    if (_hasActiveSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'لديك جلسة نشطة بالفعل. يرجى إنهاء الجلسة الحالية قبل بدء جلسة جديدة.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final double rate = _getCurrentRate();
    if (rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا النوع من الجلسات غير متاح حالياً'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // التحقق من الرصيد - تخطي للمشرفين
    final double requiredBalance = rate * 30; // مدة الجلسة الافتراضية 30 دقيقة
    print('التحقق من الرصيد: الرصيد المطلوب $requiredBalance، الرصيد الحالي $_userBalance');
    
    if (!_isAdmin && _userBalance < requiredBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('رصيد المحفظة غير كافٍ لبدء الجلسة: الرصيد المطلوب $requiredBalance كوينز، الرصيد الحالي $_userBalance كوينز'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String? createdSessionId;

    try {
      print('طلب جلسة مدفوعة نوع: $_selectedSessionType');
      try {
        createdSessionId = await ChatService.createChatSession(
          widget.currentUser.id,
          widget.astrologerId,
          _selectedSessionType,
          isFree: false, // تحديد أن هذه جلسة مدفوعة
        );
        print('تم إنشاء الجلسة المدفوعة بنجاح: $createdSessionId');
      } catch (sessionError) {
        print('خطأ في إنشاء الجلسة المدفوعة: $sessionError');
        rethrow;
      }

      if (createdSessionId != null) {
        try {
          await NotificationService.addNotification(
            widget.currentUser.id,
            'تم إنشاء جلسة جديدة بنجاح مع الفلكي ${widget.astrologerName}.',
          );
          print('تم إضافة إشعار للمستخدم بنجاح');
        } catch (notificationError) {
          // فقط تسجيل الخطأ، ولكن نستمر في التنفيذ
          print('خطأ في إضافة إشعار للمستخدم: $notificationError');
        }
      }

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء الجلسة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      print('خطأ عام في إنشاء الجلسة: $e');
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في إنشاء الجلسة: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getSessionTypeText(String type) {
    switch (type) {
      case 'text':
        return 'دردشة نصية';
      case 'audio':
        return 'مكالمة صوتية';
      case 'video':
        return 'مكالمة فيديو';
      default:
        return 'غير معروف';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canUseFreeSession =
        _freeSessionsUsed < ChatService.FREE_SESSION_LIMIT &&
            _astrologerOffersFree;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('طلب جلسة جديدة', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF191923),
      ),
      backgroundColor: const Color(0xFF191923),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF2C792)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_hasActiveSession)
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2A3F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF2C792).withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning, color: Color(0xFFF2C792)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'لديك جلسة نشطة بالفعل. يرجى إنهاء الجلسة الحالية قبل بدء جلسة جديدة.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // معلومات الفلكي
                  Card(
                    color: const Color(0xFF21202F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          UserProfileImage(
                            userId: widget.astrologerId,
                            radius: 30,
                            placeholderIcon: const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.astrologerName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (widget.astrologerImage != '') ...[
                                  const SizedBox(height: 8),
                                  Image.network(
                                    widget.astrologerImage,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // معلومات الجلسات المجانية
                  if (_astrologerOffersFree)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2A3F),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF2C792),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.star, color: Color(0xFFF2C792)),
                              SizedBox(width: 8),
                              Text(
                                'هذا الفلكي يقدم جلسات مجانية!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'الجلسة المجانية مدتها ${ChatService.FREE_SESSION_DURATION} دقيقة.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          _buildFreeSessionsIndicator(),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.card_giftcard),
                              label: const Text('طلب جلسة مجانية'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF21202F),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                disabledBackgroundColor: Colors.grey.shade800,
                                disabledForegroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: Color(0xFFF2C792),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onPressed: canUseFreeSession &&
                                      !_hasActiveSession &&
                                      !_isCheckingFreeSessionLimit
                                  ? _requestFreeSession
                                  : null,
                            ),
                          ),
                          if (_freeSessionsUsed >=
                              ChatService.FREE_SESSION_LIMIT)
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'لقد استنفدت جميع جلساتك المجانية لهذا اليوم.',
                                style: TextStyle(
                                  color: Color(0xFFF2C792),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),
                  const Text(
                    'اختر نوع الجلسة المدفوعة',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // اختيار نوع الجلسة
                  _buildSessionTypeCard(
                    'text',
                    Icons.chat,
                    'دردشة نصية',
                    'تواصل مع الفلكي عبر الرسائل النصية',
                    _astrologerRates?['text_rate'] ?? 0,
                  ),
                  const SizedBox(height: 12),
                  _buildSessionTypeCard(
                    'audio',
                    Icons.phone,
                    'مكالمة صوتية',
                    'تواصل صوتي مباشر مع الفلكي',
                    _astrologerRates?['audio_rate'] ?? 0,
                  ),
                  const SizedBox(height: 12),
                  _buildSessionTypeCard(
                    'video',
                    Icons.videocam,
                    'مكالمة فيديو',
                    'تواصل بالفيديو مباشرة مع الفلكي',
                    _astrologerRates?['video_rate'] ?? 0,
                  ),

                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF21202F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_balance_wallet,
                              color: Color(0xFFF2C792),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'رصيد المحفظة: $_userBalance كوينز',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ملاحظة توضيحية حول الرصيد
                        const Text(
                          'ملاحظة: يجب أن يكون لديك رصيد كافٍ لتغطية 30 دقيقة على الأقل قبل بدء جلسة مدفوعة.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _hasActiveSession ? null : _requestSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF21202F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        disabledBackgroundColor: Colors.grey.shade800,
                        disabledForegroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(
                            color: Color(0xFFF2C792),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: const Text('طلب جلسة مدفوعة'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionTypeCard(
    String type,
    IconData icon,
    String title,
    String description,
    double rate,
  ) {
    final bool isAvailable = rate > 0;
    final bool isSelected = _selectedSessionType == type;

    return Card(
      elevation: isSelected ? 4 : 1,
      color: const Color(0xFF21202F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? const Color(0xFFF2C792) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: isAvailable
            ? () {
                setState(() {
                  _selectedSessionType = type;
                });
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF2C792).withOpacity(0.2)
                      : const Color(0xFF2C2A3F),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? const Color(0xFFF2C792) : Colors.white70,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isAvailable ? Colors.white : Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: isAvailable ? Colors.white70 : Colors.white30,
                      ),
                    ),
                    if (rate > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'السعر: $rate كوينز / دقيقة',
                        style: TextStyle(
                          color: isAvailable
                              ? const Color(0xFFF2C792)
                              : Colors.white30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeSessionsIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        _isCheckingFreeSessionLimit
            ? const LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF2C792)),
                backgroundColor: Color(0xFF21202F),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'استخدمت $_freeSessionsUsed من أصل ${ChatService.FREE_SESSION_LIMIT} جلسات مجانية اليوم.',
                    style: const TextStyle(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_freeSessionsUsed / ChatService.FREE_SESSION_LIMIT)
                        .toDouble(),
                    backgroundColor: const Color(0xFF21202F),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFF2C792),
                    ),
                  ),
                ],
              ),
      ],
    );
  }
}
