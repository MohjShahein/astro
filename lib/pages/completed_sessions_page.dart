import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/chat_session_model.dart';
import '../services/chat_service.dart';

class CompletedSessionsPage extends StatefulWidget {
  final UserModel currentUser;

  const CompletedSessionsPage({super.key, required this.currentUser});

  @override
  _CompletedSessionsPageState createState() => _CompletedSessionsPageState();
}

class _CompletedSessionsPageState extends State<CompletedSessionsPage> {
  late Stream<QuerySnapshot> _completedSessionsStream;
  final Map<String, UserModel> _userCache = {};

  @override
  void initState() {
    super.initState();
    _completedSessionsStream = ChatService.getAstrologerSessionsByStatus(
      widget.currentUser.id,
      'completed',
    );
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
      print('Error fetching user: $e');
    }
    return null;
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
      appBar: AppBar(title: const Text('سجل الجلسات'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: _completedSessionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('لا توجد جلسات سابقة'));
          }

          // استخراج البيانات وفرزها حسب تاريخ الإنشاء (من الأحدث إلى الأقدم)
          final docs = snapshot.data!.docs;
          List<DocumentSnapshot> sortedDocs = List.from(docs);

          // محاولة فرز المستندات حسب تاريخ الإنشاء
          try {
            sortedDocs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;

              // استخدام end_time أولًا إذا كان موجودًا لأنه يمثل وقت انتهاء الجلسة
              final aEndTime = aData['end_time'] as Timestamp?;
              final bEndTime = bData['end_time'] as Timestamp?;

              if (aEndTime != null && bEndTime != null) {
                return bEndTime.compareTo(aEndTime); // ترتيب تنازلي
              }

              // استخدام created_at كبديل إذا لم يكن end_time متاحًا
              final aTime = aData['created_at'] as Timestamp?;
              final bTime = bData['created_at'] as Timestamp?;

              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return 1;
              if (bTime == null) return -1;

              return bTime.compareTo(aTime); // ترتيب تنازلي
            });
          } catch (e) {
            print('خطأ في فرز الجلسات: $e');
            // استمر بدون فرز إذا حدث خطأ
          }

          return ListView.builder(
            itemCount: sortedDocs.length,
            itemBuilder: (context, index) {
              final doc = sortedDocs[index];
              final sessionData = doc.data() as Map<String, dynamic>;
              final sessionId = doc.id;
              final ChatSessionModel session = ChatSessionModel.fromMap(
                sessionId,
                sessionData,
              );

              // Get the other participant
              final String otherUserId = session.participants.firstWhere(
                (id) => id != widget.currentUser.id,
                orElse: () => 'unknown',
              );

              return FutureBuilder<UserModel?>(
                future: _getUserInfo(otherUserId),
                builder: (context, userSnapshot) {
                  final String userName = userSnapshot.data != null
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
                              CircleAvatar(
                                backgroundImage:
                                    userSnapshot.data?.profileImageUrl != null
                                        ? NetworkImage(
                                            userSnapshot.data!.profileImageUrl!,
                                          )
                                        : null,
                                child:
                                    userSnapshot.data?.profileImageUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
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
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'تاريخ الجلسة: ${session.getFormattedStartTime()}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.timer,
                                size: 18,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'مدة الجلسة: ${session.getFormattedDuration()}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.attach_money,
                                size: 18,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'التكلفة الإجمالية: ${session.totalCost}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
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
