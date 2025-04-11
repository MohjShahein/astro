import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // إضافة لاستخدام Timer
import '../models/user_model.dart';
import '../services/chat_service.dart';
import 'chat_page.dart';
import '../services/session_manager.dart';

class ActiveSessionsPage extends StatefulWidget {
  final UserModel currentUser;

  const ActiveSessionsPage({super.key, required this.currentUser});

  @override
  _ActiveSessionsPageState createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends State<ActiveSessionsPage> {
  late Stream<QuerySnapshot> _activeSessionsStream;
  final Map<String, UserModel> _userCache = {};
  bool _isLoading = true;
  String? _error;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _sessionTimer; // مؤقت لتحديث مدة الجلسات

  @override
  void initState() {
    super.initState();
    _initializeStream();
    // بدء المؤقت لتحديث مدة الجلسات كل ثانية
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // تحديث الواجهة لعرض المدة المحدثة
        });
      }
    });
  }

  @override
  void dispose() {
    // إلغاء المؤقت عند التخلص من الصفحة
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _initializeStream() {
    try {
      // تحديد نوع الاستعلام بناءً على نوع المستخدم
      if (widget.currentUser.userType == 'astrologer') {
        // للمنجمين: استخدم الاستعلام الخاص بجلسات المنجم
        print('استعلام عن جلسات المنجم الفعالة: ${widget.currentUser.id}');
        _activeSessionsStream = ChatService.getAstrologerSessionsByStatus(
          widget.currentUser.id,
          'active',
        );
      } else {
        // للمستخدمين العاديين: استخدم استعلامين معًا

        print(
            'استعلام عن جلسات المستخدم العادي الفعالة: ${widget.currentUser.id}');

        // الاستعلام الأول: باستخدام مصفوفة المشاركين (يعمل مع الجلسات الحديثة)
        _activeSessionsStream = ChatService.getUserSessionsByStatus(
          widget.currentUser.id,
          'active',
        );

        // الاستعلام الثاني: باستخدام معرف المستخدم (قد يعمل مع الجلسات القديمة)
        // نستخدم Stream جديد ونطبق عليه الحالة عند عرض النتائج
        // لا يمكننا دمج Streams بسهولة، لذلك نستخدم واحدًا فقط ونضيف استعلامًا احتياطيًا

        // جدولة استعلام ثانوي باستخدام user_id بعد ثانيتين في حالة عدم وجود جلسات
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            // التحقق من أن الصفحة ما زالت نشطة
            // إذا لم يكن هناك جلسات نشطة باستخدام الاستعلام الأول، نجرب الاستعلام الثاني
            setState(() {
              // استخدام استعلام احتياطي
              _activeSessionsStream =
                  ChatService.getUserSessionsByUserIdAndStatus(
                widget.currentUser.id,
                'active',
              );
              print(
                  'تم تبديل الاستعلام إلى User ID للبحث عن المزيد من الجلسات');
            });
          }
        });
      }

      setState(() {
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'حدث خطأ أثناء تحميل الجلسات: ${e.toString()}';
      });
      print('خطأ في تهيئة stream الجلسات: $e');
    }
  }

  Future<UserModel?> _getUserInfo(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        UserModel user = UserModel.fromMap(
          userId,
          userDoc.data() as Map<String, dynamic>,
        );
        // Cache the user
        _userCache[userId] = user;
        return user;
      }
    } catch (e) {
      print('خطأ في الحصول على معلومات المستخدم: $e');
      setState(() {
        _error = 'حدث خطأ أثناء تحميل معلومات المستخدم';
      });
    }
    return null;
  }

  Future<void> _endSession(String sessionId) async {
    // إظهار مؤشر التحميل
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      await ChatService.endSession(sessionId);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنهاء الجلسة بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        print('خطأ في إنهاء الجلسة: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنهاء الجلسة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  void _navigateToChat(String sessionId, String otherUserId) {
    // Navigate to chat page with the session ID
    // Implementation depends on your navigation setup
    // This is a placeholder
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          sessionId: sessionId,
          currentUserId: widget.currentUser.id,
          otherUserId: otherUserId,
          isPaid: true,
        ),
      ),
    );
  }

  String _calculateSessionDuration(Timestamp startTime) {
    final now = DateTime.now();
    final start = startTime.toDate();
    final difference = now.difference(start);

    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    if (hours > 0) {
      return '$hours ساعة و $minutes دقيقة و $seconds ثانية';
    } else if (minutes > 0) {
      return '$minutes دقيقة و $seconds ثانية';
    } else {
      return '$seconds ثانية';
    }
  }

  // دالة جديدة لحساب الوقت المتبقي للجلسات المجانية
  String _calculateRemainingTime(Timestamp startTime, int freeSessionLimit) {
    final now = DateTime.now();
    final start = startTime.toDate();
    final sessionDuration = now.difference(start);

    // تحويل حد الجلسة المجانية من دقائق إلى ثواني
    final limitInSeconds = freeSessionLimit * 60;
    final remainingSeconds = limitInSeconds - sessionDuration.inSeconds;

    if (remainingSeconds <= 0) {
      return 'انتهى الوقت';
    }

    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    final seconds = remainingSeconds % 60;

    if (hours > 0) {
      return '$hours ساعة و $minutes دقيقة و $seconds ثانية';
    } else if (minutes > 0) {
      return '$minutes دقيقة و $seconds ثانية';
    } else {
      return '$seconds ثانية';
    }
  }

  Future<void> _showEndSessionConfirmation(String sessionId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('تأكيد إنهاء الجلسة'),
          content: const SingleChildScrollView(
            child: Text(
              'هل أنت متأكد من رغبتك في إنهاء هذه الجلسة؟\n'
              'سيتم احتساب الوقت المستهلك حتى الآن والمبلغ المستحق.',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('إنهاء الجلسة'),
              onPressed: () async {
                Navigator.of(context).pop();

                // التحقق من صلاحية إنهاء الجلسة
                try {
                  final validationResult =
                      await SessionManager.validateSessionEnd(
                    sessionId,
                    widget.currentUser.id,
                  );

                  if (!validationResult['isValid']) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'لا يمكن إنهاء الجلسة: ${validationResult['error']}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  // إنهاء الجلسة إذا كانت صالحة
                  await _endSession(sessionId);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ في التحقق من صلاحية الجلسة: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الجلسات النشطة'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: _activeSessionsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('خطأ: ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text('لا توجد جلسات نشطة'),
                      );
                    }

                    // استخراج البيانات وفرزها حسب وقت آخر رسالة أو تاريخ الإنشاء (من الأحدث إلى الأقدم)
                    final docs = snapshot.data!.docs;
                    List<DocumentSnapshot> sortedDocs = List.from(docs);

                    // محاولة فرز المستندات
                    try {
                      sortedDocs.sort((a, b) {
                        final aData = a.data() as Map<String, dynamic>;
                        final bData = b.data() as Map<String, dynamic>;

                        // استخدام last_message_at أولًا إذا كان موجودًا
                        final aLastMessage =
                            aData['last_message_at'] as Timestamp?;
                        final bLastMessage =
                            bData['last_message_at'] as Timestamp?;

                        if (aLastMessage != null && bLastMessage != null) {
                          return bLastMessage
                              .compareTo(aLastMessage); // ترتيب تنازلي
                        }

                        // استخدام created_at كبديل إذا لم يكن last_message_at متاحًا
                        final aCreated = aData['created_at'] as Timestamp?;
                        final bCreated = bData['created_at'] as Timestamp?;

                        if (aCreated == null && bCreated == null) return 0;
                        if (aCreated == null) return 1;
                        if (bCreated == null) return -1;

                        return bCreated.compareTo(aCreated); // ترتيب تنازلي
                      });
                    } catch (e) {
                      print('خطأ في فرز الجلسات النشطة: $e');
                      // استمر بدون فرز إذا حدث خطأ
                    }

                    return ListView.builder(
                      itemCount: sortedDocs.length,
                      itemBuilder: (context, index) {
                        final session = sortedDocs[index];
                        final sessionData =
                            session.data() as Map<String, dynamic>;

                        // الحصول على معرف المستخدم الآخر بطريقة أكثر مرونة
                        String otherUserId;

                        // المنهج الأساسي: استخدام مصفوفة المشاركين
                        if (sessionData['participants'] != null &&
                            (sessionData['participants'] as List).isNotEmpty &&
                            (sessionData['participants'] as List)
                                .contains(widget.currentUser.id)) {
                          // إذا كان المستخدم الحالي موجودًا في مصفوفة المشاركين، نحصل على المستخدم الآخر
                          otherUserId = (sessionData['participants'] as List)
                              .firstWhere((id) => id != widget.currentUser.id,
                                  orElse: () => '');
                        } else {
                          // المنهج البديل: استخدام حقول user_id و astrologer_id
                          final currentUserId = widget.currentUser.id;
                          final userId = sessionData['user_id'];
                          final astrologerId = sessionData['astrologer_id'];

                          // إذا كان المستخدم الحالي هو المستخدم العادي، نعرض معرف الفلكي
                          if (userId == currentUserId) {
                            otherUserId = astrologerId;
                          }
                          // إذا كان المستخدم الحالي هو الفلكي، نعرض معرف المستخدم العادي
                          else if (astrologerId == currentUserId) {
                            otherUserId = userId;
                          }
                          // إذا لم يكن أي منهما، نستخدم معرف المستخدم العادي بشكل افتراضي
                          else {
                            otherUserId = userId;
                            print(
                                'تحذير: المستخدم الحالي ليس المستخدم ولا الفلكي في هذه الجلسة');
                          }
                        }

                        final isFreeSession =
                            sessionData['is_free_session'] ?? false;
                        final freeSessionLimit =
                            sessionData['free_session_limit'] ??
                                15; // الحد الافتراضي 15 دقيقة

                        return FutureBuilder<UserModel?>(
                          future: _getUserInfo(otherUserId),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              );
                            }

                            if (userSnapshot.hasError) {
                              return const Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(Icons.error),
                                  ),
                                  title: Text(
                                    'خطأ في تحميل معلومات المستخدم',
                                  ),
                                ),
                              );
                            }

                            final user = userSnapshot.data;
                            if (user == null) {
                              return const Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text('مستخدم غير معروف'),
                                ),
                              );
                            }

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      leading: CircleAvatar(
                                        backgroundImage:
                                            user.profileImageUrl != null
                                                ? NetworkImage(
                                                    user.profileImageUrl!,
                                                  )
                                                : null,
                                        child: user.profileImageUrl == null
                                            ? const Icon(Icons.person)
                                            : null,
                                      ),
                                      title: Text(
                                        '${user.firstName ?? ''} ${user.lastName ?? ''}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _getSessionTypeText(
                                          sessionData['session_type'],
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.chat),
                                            tooltip: 'بدء المحادثة',
                                            onPressed: () => _navigateToChat(
                                              session.id,
                                              otherUserId,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.stop_circle_outlined,
                                            ),
                                            color: Colors.red,
                                            tooltip: 'إنهاء الجلسة',
                                            onPressed: () =>
                                                _showEndSessionConfirmation(
                                              session.id,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(),
                                    if (sessionData['start_time'] != null) ...[
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.timer,
                                            size: 20,
                                            color: Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                    'مدة الجلسة الحالية:'),
                                                Text(
                                                  _calculateSessionDuration(
                                                    sessionData['start_time'],
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (isFreeSession) ...[
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.hourglass_bottom,
                                              size: 20,
                                              color: Colors.orange,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'الوقت المتبقي (الحد: $freeSessionLimit دقيقة):',
                                                  ),
                                                  Text(
                                                    _calculateRemainingTime(
                                                      sessionData['start_time'],
                                                      freeSessionLimit,
                                                    ),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          _calculateRemainingTime(
                                                                    sessionData[
                                                                        'start_time'],
                                                                    freeSessionLimit,
                                                                  ) ==
                                                                  'انتهى الوقت'
                                                              ? Colors.red
                                                              : Colors.orange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_calculateRemainingTime(
                                              sessionData['start_time'],
                                              freeSessionLimit,
                                            ) ==
                                            'انتهى الوقت')
                                          Container(
                                            margin:
                                                const EdgeInsets.only(top: 8),
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                8,
                                              ),
                                              border: Border.all(
                                                color: Colors.red,
                                              ),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(
                                                  Icons.warning,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'انتهى وقت الجلسة المجانية. يرجى إنهاء الجلسة',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
    );
  }
}
