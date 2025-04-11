import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/review_service.dart';
import 'request_session_page.dart';
import '../components/user_profile_image.dart';
import 'add_review_page.dart';

class AstrologerProfilePage extends StatefulWidget {
  final String currentUserId;
  final String astrologerId;

  const AstrologerProfilePage({
    super.key,
    required this.currentUserId,
    required this.astrologerId,
  });

  @override
  _AstrologerProfilePageState createState() => _AstrologerProfilePageState();
}

class _AstrologerProfilePageState extends State<AstrologerProfilePage> {
  UserModel? _astrologer;
  UserModel? _currentUser;
  bool _isLoading = true;
  double _averageRating = 0.0;
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic>? _rates;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load astrologer data
      final astrologerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.astrologerId)
          .get();

      if (astrologerDoc.exists) {
        _astrologer = UserModel.fromMap(
          widget.astrologerId,
          astrologerDoc.data() as Map<String, dynamic>,
        );
      }

      // Load current user data
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();

      if (currentUserDoc.exists) {
        _currentUser = UserModel.fromMap(
          widget.currentUserId,
          currentUserDoc.data() as Map<String, dynamic>,
        );
      }

      // Load astrologer rates
      _rates = await ChatService.getAstrologerRate(widget.astrologerId);

      // Load reviews
      await _loadReviews();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading astrologer data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('خطأ في تحميل بيانات الفلكي: $e')));
    }
  }

  Future<void> _loadReviews() async {
    try {
      // Get average rating
      _averageRating = await ReviewService.getAverageRating(
        widget.astrologerId,
      );

      // Get reviews - convert stream to future by getting the first snapshot
      final reviewsSnapshot =
          await ReviewService.getReviews(widget.astrologerId).first;
      final reviews = reviewsSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'userId': data['user_id'],
          'rating': data['rating'],
          'comment': data['review_text'],
          'timestamp': data['created_at'],
          'userName': '',
        };
      }).toList();

      // Get user names for reviews
      for (var review in reviews) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(review['userId'])
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          review['userName'] =
              '${userData['first_name'] ?? ''} ${userData['last_name'] ?? ''}';
        }
      }

      setState(() {
        _reviews = reviews;
      });
    } catch (e) {
      print('Error loading reviews: $e');
    }
  }

  void _requestSession() {
    if (_astrologer == null || _currentUser == null) return;

    final double textRate = (_rates?['text_rate'] ?? 0).toDouble();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RequestSessionPage(
          currentUser: _currentUser!,
          astrologerId: _astrologer!.id,
          astrologerName: _astrologer!.fullName,
          astrologerImage: _astrologer!.profileImageUrl ?? '',
          sessionPrice: textRate,
          offersFreeSession: _astrologer!.offersFreeSession,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF191923),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191923),
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _astrologer == null
              ? const Center(
                  child: Text(
                    'لم يتم العثور على الفلكي',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile header
                      Center(
                        child: Column(
                          children: [
                            UserProfileImage(
                              userId: _astrologer!.id,
                              radius: 60,
                              placeholderIcon: const Icon(Icons.person,
                                  size: 60, color: Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '${_astrologer!.firstName ?? ''} ${_astrologer!.lastName ?? ''}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _averageRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // About section
                      if (_astrologer!.aboutMe != null) ...[
                        const Text(
                          'نبذة عني',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: const Color(0xFF191923),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _astrologer!.aboutMe!,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Services section
                      if (_astrologer!.services != null &&
                          _astrologer!.services!.isNotEmpty) ...[
                        const Text(
                          'الخدمات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: const Color(0xFF191923),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _astrologer!.services!.map((service) {
                                return Chip(
                                  label: Text(
                                    service,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: const Color(0xFF1E1E2A),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Rates section
                      if (_rates != null) ...[
                        const Text(
                          'الأسعار',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Card(
                          color: const Color(0xFF191923),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _buildRateRow(
                                  'دردشة نصية',
                                  Icons.message,
                                  (_rates!['text_rate'] ?? 0).toDouble(),
                                ),
                                const Divider(color: Colors.white24),
                                _buildRateRow(
                                  'مكالمة صوتية',
                                  Icons.phone,
                                  (_rates!['audio_rate'] ?? 0).toDouble(),
                                ),
                                const Divider(color: Colors.white24),
                                _buildRateRow(
                                  'مكالمة فيديو',
                                  Icons.videocam,
                                  (_rates!['video_rate'] ?? 0).toDouble(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Reviews section
                      const Text(
                        'التقييمات',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Add review button - only shown for regular users, not for astrologers
                      if (_currentUser != null &&
                          _currentUser!.userType != 'astrologer')
                        FutureBuilder<bool>(
                          future: ReviewService.hasUserReviewedAstrologer(
                              widget.currentUserId, widget.astrologerId),
                          builder: (context, snapshot) {
                            final bool hasReviewed = snapshot.data ?? false;

                            // إذا كان المستخدم قد قيّم الفلكي مسبقًا، نخفي الزر تمامًا
                            if (hasReviewed) {
                              return const SizedBox(); // زر مخفي
                            }

                            // إظهار زر التقييم فقط إذا لم يقم المستخدم بتقييم الفلكي من قبل
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  // نتأكد من أن لدينا بيانات الفلكي والمستخدم الحالي
                                  if (_astrologer == null ||
                                      _currentUser == null) {
                                    return;
                                  }

                                  // انتقل إلى صفحة إضافة تقييم
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddReviewPage(
                                        userId: widget.currentUserId,
                                        astrologerId: widget.astrologerId,
                                        astrologerName: _astrologer!.fullName,
                                      ),
                                    ),
                                  );

                                  // إعادة تحميل التقييمات بعد العودة من صفحة إضافة التقييم
                                  _loadReviews();
                                },
                                icon:
                                    const Icon(Icons.star, color: Colors.amber),
                                label: const Text('أضف تقييمك'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E1E2A),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      _reviews.isEmpty
                          ? const Card(
                              color: Color(0xFF191923),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    'لا توجد تقييمات بعد',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: _reviews.map((review) {
                                return Card(
                                  color: const Color(0xFF191923),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              review['userName'] ?? 'مستخدم',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Spacer(),
                                            Row(
                                              children: List.generate(
                                                5,
                                                (index) => Icon(
                                                  index <
                                                          (review['rating'] ??
                                                              0)
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          review['comment'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                    ],
                  ),
                ),
      bottomNavigationBar: _isLoading || _astrologer == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _requestSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E2A),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'بدء المحادثة',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
    );
  }

  Widget _buildRateRow(String title, IconData icon, double rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Text(
            rate > 0 ? '$rate كوينز / دقيقة' : 'غير متاح',
            style: TextStyle(
              color: rate > 0 ? Colors.white : Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
