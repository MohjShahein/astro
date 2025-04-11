import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/chat_session_model.dart';
import '../services/chat_service.dart';
import '../components/user_profile_image.dart';

class PendingSessionsPage extends StatefulWidget {
  final UserModel currentUser;

  const PendingSessionsPage({super.key, required this.currentUser});

  @override
  _PendingSessionsPageState createState() => _PendingSessionsPageState();
}

class _PendingSessionsPageState extends State<PendingSessionsPage> {
  late Stream<QuerySnapshot> _pendingSessionsStream;
  final Map<String, UserModel> _userCache = {};

  @override
  void initState() {
    super.initState();
    _pendingSessionsStream = ChatService.getAstrologerSessionsByStatus(
      widget.currentUser.id,
      'pending',
    );
  }

  Future<UserModel?> _getUserInfo(String userId) async {
    // Check cache first
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }

    try {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
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
      print('Error fetching user: $e');
    }
    return null;
  }

  Future<void> _acceptSession(String sessionId) async {
    try {
      await ChatService.acceptPaidChatSession(sessionId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم قبول الجلسة بنجاح')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في قبول الجلسة: $e')));
    }
  }

  Future<void> _cancelSession(String sessionId) async {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('سبب الإلغاء'),
            content: TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'أدخل سبب إلغاء الجلسة',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                child: const Text('إلغاء'),
                onPressed: () => Navigator.pop(context),
              ),
              TextButton(
                child: const Text('تأكيد'),
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await ChatService.cancelPaidChatSession(
                      sessionId,
                      reasonController.text.isNotEmpty
                          ? reasonController.text
                          : 'تم الإلغاء من قبل المنجم',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إلغاء الجلسة بنجاح')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ في إلغاء الجلسة: $e')),
                    );
                  }
                },
              ),
            ],
          ),
    );
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
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات الجلسات'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: _pendingSessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد طلبات جلسات حالياً'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final sessionData = doc.data() as Map<String, dynamic>;
              final sessionId = doc.id;
              final ChatSessionModel session = ChatSessionModel.fromMap(
                sessionId,
                sessionData,
              );

              // Get the other participant (user)
              final String userId = session.participants.firstWhere(
                (id) => id != widget.currentUser.id,
                orElse: () => 'unknown',
              );

              return FutureBuilder<UserModel?>(
                future: _getUserInfo(userId),
                builder: (context, userSnapshot) {
                  final String userName =
                      userSnapshot.data != null
                          ? '${userSnapshot.data!.firstName ?? ''} ${userSnapshot.data!.lastName ?? ''}'
                          : 'مستخدم غير معروف';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserProfileImage(
                                userId: userId,
                                radius: 20,
                                placeholderIcon: const Icon(
                                  Icons.person,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'نوع الجلسة: ${_getSessionTypeText(session.sessionType)}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.attach_money,
                                size: 18,
                                color: Colors.green,
                              ),
                              Text(
                                'السعر: ${session.ratePerMinute} / دقيقة',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 18,
                                color: Colors.blue,
                              ),
                              Text(
                                'تاريخ الطلب: ${session.createdAt.toString().substring(0, 16)}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'قبول',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () => _acceptSession(sessionId),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'رفض',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                  onPressed: () => _cancelSession(sessionId),
                                ),
                              ),
                            ],
                          ),
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
