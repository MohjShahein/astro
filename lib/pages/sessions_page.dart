import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/chat_session_model.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import 'active_sessions_page.dart';
import 'pending_sessions_page.dart';
import 'completed_sessions_page.dart';
import 'chat_page.dart';
import '../components/user_profile_image.dart';

class SessionsPage extends StatefulWidget {
  final String userId;

  const SessionsPage({super.key, required this.userId});

  @override
  _SessionsPageState createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await AuthService.getUserData(widget.userId);
      setState(() {
        _currentUser = userData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_currentUser == null) {
      return const Center(child: Text('لم يتم العثور على بيانات المستخدم'));
    }

    // Check if user is an astrologer
    final bool isAstrologer = _currentUser!.userType == 'astrologer';

    if (isAstrologer) {
      // Astrologer view with tabs for different session statuses
      return Scaffold(
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: const Text('جلساتي'),
                  pinned: true,
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'قيد الانتظار'),
                      Tab(text: 'نشطة'),
                      Tab(text: 'مكتملة'),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                PendingSessionsPage(currentUser: _currentUser!),
                ActiveSessionsPage(currentUser: _currentUser!),
                CompletedSessionsPage(currentUser: _currentUser!),
              ],
            ),
          ),
        ),
      );
    } else {
      // Regular user view with all their sessions
      return Scaffold(
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  title: const Text('محادثاتي'),
                  pinned: true,
                  floating: true,
                  forceElevated: innerBoxIsScrolled,
                  bottom: TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'قيد الانتظار'),
                      Tab(text: 'نشطة'),
                      Tab(text: 'مكتملة'),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildUserSessionsTab(status: 'pending'),
                _buildUserSessionsTab(status: 'active'),
                _buildUserSessionsTab(status: 'completed'),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildUserSessionsTab({required String status}) {
    return StreamBuilder<QuerySnapshot>(
      stream: ChatService.getUserSessionsByStatus(widget.userId, status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('Error loading sessions: ${snapshot.error}');
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('عذراً، حدث خطأ أثناء تحميل الجلسات'),
                Text(
                  'يرجى المحاولة مرة أخرى لاحقاً',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          String message = '';
          switch (status) {
            case 'pending':
              message = 'لا توجد جلسات معلقة';
              break;
            case 'active':
              message = 'لا توجد جلسات نشطة';
              break;
            case 'completed':
              message = 'لا توجد جلسات مكتملة';
              break;
            default:
              message = 'لا توجد جلسات';
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(message),
                const SizedBox(height: 8),
                const Text(
                  'اختر فلكياً وابدأ جلستك',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // Get sessions from snapshot
        final docs = snapshot.data!.docs;

        // فرز الجلسات حسب تاريخ الإنشاء (الأحدث أولاً)
        final sessions = docs.map((doc) {
          final sessionData = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'data': sessionData,
          };
        }).toList();

        // فرز حسب آخر رسالة
        sessions.sort((a, b) {
          final aData = a['data'] as Map<String, dynamic>;
          final bData = b['data'] as Map<String, dynamic>;
          final aTime =
              aData['last_message_at'] as Timestamp? ?? Timestamp.now();
          final bTime =
              bData['last_message_at'] as Timestamp? ?? Timestamp.now();
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (context, index) {
            final sessionDoc = sessions[index];
            final sessionId = sessionDoc['id'] as String;
            final sessionData = sessionDoc['data'] as Map<String, dynamic>;
            final ChatSessionModel session = ChatSessionModel.fromMap(
              sessionId,
              sessionData,
            );

            // Get the other participant (astrologer)
            final String otherUserId = session.participants.firstWhere(
              (id) => id != widget.userId,
              orElse: () => '',
            );

            return FutureBuilder<UserModel?>(
              future: AuthService.getUserData(otherUserId),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: CircularProgressIndicator(),
                      ),
                      title: Text('جاري التحميل...'),
                    ),
                  );
                }

                final user = userSnapshot.data;
                if (user == null) {
                  return const Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Icon(Icons.error)),
                      title: Text('فلكي غير معروف'),
                    ),
                  );
                }

                // معلومات الجلسة
                String sessionStatus = '';
                Color statusColor = Colors.grey;
                IconData statusIcon = Icons.help;

                switch (session.status) {
                  case 'pending':
                    sessionStatus = 'معلقة';
                    statusColor = Colors.orange;
                    statusIcon = Icons.hourglass_empty;
                    break;
                  case 'active':
                    sessionStatus = 'نشطة';
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                    break;
                  case 'completed':
                    sessionStatus = 'مكتملة';
                    statusColor = Colors.blue;
                    statusIcon = Icons.done_all;
                    break;
                  case 'cancelled':
                    sessionStatus = 'ملغاة';
                    statusColor = Colors.red;
                    statusIcon = Icons.cancel;
                    break;
                }

                // معلومات نوع الجلسة
                String sessionType = '';
                IconData typeIcon = Icons.chat;

                switch (session.sessionType) {
                  case 'text':
                    sessionType = 'دردشة نصية';
                    typeIcon = Icons.chat;
                    break;
                  case 'audio':
                    sessionType = 'مكالمة صوتية';
                    typeIcon = Icons.phone;
                    break;
                  case 'video':
                    sessionType = 'مكالمة فيديو';
                    typeIcon = Icons.videocam;
                    break;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: InkWell(
                    onTap: () {
                      // Open chat page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatPage(
                            sessionId: sessionId,
                            currentUserId: widget.userId,
                            otherUserId: otherUserId,
                            isPaid: !session.isPaid,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              UserProfileImage(
                                userId: otherUserId,
                                radius: 24,
                                placeholderIcon: const Icon(
                                  Icons.person,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${user.firstName ?? ''} ${user.lastName ?? ''}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          typeIcon,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          sessionType,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Chip(
                                label: Text(
                                  sessionStatus,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                avatar: Icon(
                                  statusIcon,
                                  size: 16,
                                  color: statusColor,
                                ),
                                backgroundColor: statusColor.withOpacity(0.1),
                              ),
                            ],
                          ),
                          if (session.startTime != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'تاريخ البدء: ${session.getFormattedStartTime()}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          if (session.totalDuration > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'مدة الجلسة: ${session.getFormattedDuration()}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
