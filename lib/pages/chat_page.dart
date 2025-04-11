import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/chat_message_model.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class ChatPage extends StatefulWidget {
  final String sessionId;
  final String currentUserId;
  final String otherUserId;
  final bool isPaid;

  const ChatPage({
    super.key,
    required this.sessionId,
    required this.currentUserId,
    required this.otherUserId,
    this.isPaid = false,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  late Stream<QuerySnapshot> _messagesStream;
  String _otherUserName = 'المستخدم';
  bool _isLoading = true;
  DocumentSnapshot? _sessionDoc;
  bool _isSessionActive = true;
  Timer? _sessionTimer;

  @override
  void initState() {
    super.initState();
    _messagesStream = ChatService.getMessages(widget.sessionId);
    _loadOtherUserInfo();
    _loadSessionInfo();

    // إضافة مؤقت لتحديث الواجهة كل ثانية
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
    _sessionTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOtherUserInfo() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _otherUserName =
              '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}';
          if (_otherUserName.trim().isEmpty) {
            _otherUserName = 'المستخدم';
          }
        });
      }
    } catch (e) {
      print('Error loading user info: $e');
    }
  }

  Future<void> _loadSessionInfo() async {
    try {
      _sessionDoc = await FirebaseFirestore.instance
          .collection('chat_sessions')
          .doc(widget.sessionId)
          .get();

      if (_sessionDoc!.exists) {
        final sessionData = _sessionDoc!.data() as Map<String, dynamic>;
        setState(() {
          _isSessionActive =
              !widget.isPaid || sessionData['status'] == 'active';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isSessionActive = false;
        });
      }
    } catch (e) {
      print('Error loading session info: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    if (!_isSessionActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن إرسال رسائل في هذه الجلسة')),
      );
      return;
    }

    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await ChatService.sendMessage(
        widget.sessionId,
        message,
        widget.currentUserId,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في إرسال الرسالة: $e')));
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

  Widget _buildSessionStatusBanner() {
    final sessionData = _sessionDoc!.data() as Map<String, dynamic>;
    final String status = sessionData['status'];
    final bool isFreeSession = sessionData['is_free_session'] ?? false;

    // تعديل لتحويل القيمة إلى int بأمان
    final int freeSessionLimit = sessionData['free_session_limit'] is double
        ? (sessionData['free_session_limit'] as double).toInt()
        : (sessionData['free_session_limit'] ?? 15);

    final Timestamp? startTime = sessionData['start_time'];

    Color bannerColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'pending':
        bannerColor = AppTheme.secondaryVariantColor;
        statusText = 'في انتظار قبول الفلكي';
        statusIcon = Icons.hourglass_empty;
        break;
      case 'active':
        bannerColor = AppTheme.secondaryVariantColor;
        statusText = 'الجلسة نشطة';
        statusIcon = Icons.check_circle;
        break;
      case 'completed':
        bannerColor = AppTheme.secondaryVariantColor;
        statusText = 'الجلسة منتهية';
        statusIcon = Icons.done_all;
        break;
      case 'cancelled':
        bannerColor = AppTheme.secondaryVariantColor;
        statusText = 'الجلسة ملغاة';
        statusIcon = Icons.cancel;
        break;
      default:
        bannerColor = AppTheme.secondaryVariantColor;
        statusText = 'غير معروف';
        statusIcon = Icons.help;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: bannerColor,
          child: Row(
            children: [
              Icon(statusIcon, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              if (status == 'active' && !isFreeSession)
                Text(
                  'السعر: ${sessionData['rate_per_minute']} / دقيقة',
                  style: const TextStyle(color: Colors.white),
                ),
              if (status == 'active' && isFreeSession)
                const Text(
                  'جلسة مجانية',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        // إضافة مؤقت للجلسات المجانية
        if (status == 'active' && isFreeSession && startTime != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: _calculateRemainingTime(startTime, freeSessionLimit) ==
                    'انتهى الوقت'
                ? AppTheme.secondaryColor
                : AppTheme.secondaryVariantColor,
            child: Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 18,
                  color: _calculateRemainingTime(startTime, freeSessionLimit) ==
                          'انتهى الوقت'
                      ? AppTheme.errorColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'الوقت المتبقي: ${_calculateRemainingTime(startTime, freeSessionLimit)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        _calculateRemainingTime(startTime, freeSessionLimit) ==
                                'انتهى الوقت'
                            ? AppTheme.errorColor
                            : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
        // تحذير عند انتهاء وقت الجلسة المجانية
        if (status == 'active' &&
            isFreeSession &&
            startTime != null &&
            _calculateRemainingTime(startTime, freeSessionLimit) ==
                'انتهى الوقت')
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: AppTheme.secondaryColor,
            child: const Row(
              children: [
                Icon(Icons.warning, size: 18, color: AppTheme.errorColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'انتهى وقت الجلسة المجانية، سيتم إنهاء الجلسة قريباً',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_otherUserName),
        centerTitle: true,
        actions: widget.isPaid
            ? [
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('chat_sessions')
                      .doc(widget.sessionId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return Container();

                    final sessionData =
                        snapshot.data!.data() as Map<String, dynamic>?;
                    if (sessionData == null) return Container();

                    final bool isActive = sessionData['status'] == 'active';
                    final Timestamp? startTime = sessionData['start_time'];

                    if (!isActive || startTime == null) return Container();

                    final now = DateTime.now();
                    final start = startTime.toDate();
                    final difference = now.difference(start);

                    final minutes = difference.inMinutes;
                    final seconds = difference.inSeconds % 60;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$minutes:${seconds.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Session status banner for paid sessions
                if (widget.isPaid && _sessionDoc != null)
                  _buildSessionStatusBanner(),

                // Messages list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('خطأ: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'لا توجد رسائل بعد. ابدأ المحادثة الآن!',
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          final doc = snapshot.data!.docs[index];
                          final messageData =
                              doc.data() as Map<String, dynamic>;
                          final messageId = doc.id;
                          final ChatMessageModel message =
                              ChatMessageModel.fromMap(
                            messageId,
                            messageData,
                          );

                          final bool isCurrentUser =
                              message.userId == widget.currentUserId;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: isCurrentUser
                                  ? MainAxisAlignment.end
                                  : MainAxisAlignment.start,
                              children: [
                                if (!isCurrentUser)
                                  const CircleAvatar(
                                    radius: 16,
                                    child: Icon(Icons.person, size: 16),
                                  ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isCurrentUser
                                          ? AppTheme.primaryColor
                                              .withOpacity(0.2)
                                          : AppTheme.secondaryVariantColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          message.message,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          message.getFormattedTime(),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isCurrentUser
                                                ? AppTheme.primaryColor
                                                : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (isCurrentUser) const SizedBox(width: 8),
                                if (isCurrentUser)
                                  const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryColor,
                                    child: Icon(
                                      Icons.person,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Message input
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.attach_file,
                            color: Colors.white70),
                        onPressed: _isSessionActive
                            ? () {
                                // Implement file attachment functionality
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'سيتم دعم إرفاق الملفات قريبًا',
                                    ),
                                  ),
                                );
                              }
                            : null,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'اكتب رسالتك هنا...',
                            hintStyle: TextStyle(color: Colors.white60),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(color: Colors.white),
                          enabled: _isSessionActive,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send),
                        color: AppTheme.primaryColor,
                        onPressed: _isSessionActive ? _sendMessage : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
