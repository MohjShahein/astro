import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new review record
  static Future<void> addReview(String userId, String astrologistId, int rating,
      String reviewText) async {
    await _firestore.collection('reviews').add({
      'user_id': userId,
      'astrologist_id': astrologistId,
      'rating': rating,
      'review_text': reviewText,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Retrieves all reviews for a specific astrologer
  static Stream<QuerySnapshot> getAstrologistReviews(String astrologistId) {
    return _firestore
        .collection('reviews')
        .where('astrologist_id', isEqualTo: astrologistId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Retrieves all reviews for a specific astrologer without sorting
  static Stream<QuerySnapshot> getReviews(String astrologistId) {
    return _firestore
        .collection('reviews')
        .where('astrologist_id', isEqualTo: astrologistId)
        .snapshots();
  }

  /// Retrieves all reviews by a specific user
  static Stream<QuerySnapshot> getUserReviews(String userId) {
    return _firestore
        .collection('reviews')
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  /// Calculates average rating for an astrologer
  static Future<double> calculateAverageRating(String astrologistId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('reviews')
        .where('astrologist_id', isEqualTo: astrologistId)
        .get();

    if (snapshot.docs.isEmpty) return 0.0;

    double totalRating = 0;
    for (var doc in snapshot.docs) {
      totalRating += (doc.data() as Map<String, dynamic>)['rating'] as int;
    }
    return totalRating / snapshot.docs.length;
  }

  /// Gets the average rating for an astrologer
  static Future<double> getAverageRating(String astrologistId) async {
    return await calculateAverageRating(astrologistId);
  }

  /// التحقق مما إذا كان المستخدم قد قام بتقييم فلكي معين مسبقًا
  static Future<bool> hasUserReviewedAstrologer(
      String userId, String astrologistId) async {
    try {
      // البحث عن تقييمات للمستخدم لهذا الفلكي
      QuerySnapshot snapshot = await _firestore
          .collection('reviews')
          .where('user_id', isEqualTo: userId)
          .where('astrologist_id', isEqualTo: astrologistId)
          .get();

      // إذا وجد تقييم واحد على الأقل، فهذا يعني أن المستخدم قيّم هذا الفلكي من قبل
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('خطأ في التحقق من تقييمات المستخدم: $e');
      return false; // في حالة حدوث خطأ، نفترض أنه لم يقم بالتقييم بعد
    }
  }
}
