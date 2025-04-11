import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// الحصول على بيانات مستخدم بواسطة معرفه
  static Future<UserModel?> getUserById(String userId) async {
    try {
      final docSnapshot =
          await _firestore.collection('users').doc(userId).get();

      if (!docSnapshot.exists) {
        return null;
      }

      return UserModel.fromMap(docSnapshot.id, docSnapshot.data()!);
    } catch (e) {
      print('خطأ في الحصول على بيانات المستخدم: $e');
      return null;
    }
  }

  /// الحصول على معلومات المنجمين المعتمدين
  static Stream<QuerySnapshot> getApprovedAstrologers() {
    return _firestore
        .collection('users')
        .where('user_type', isEqualTo: 'astrologer')
        .where('astrologer_status', isEqualTo: 'approved')
        .snapshots();
  }

  /// تحديث بيانات المستخدم
  static Future<void> updateUserData(
      String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      print('خطأ في تحديث بيانات المستخدم: $e');
      rethrow;
    }
  }

  /// البحث عن المنجمين بالاسم
  static Future<List<UserModel>> searchAstrologers(String query) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'astrologer')
          .where('astrologer_status', isEqualTo: 'approved')
          .get();

      if (query.isEmpty) {
        return querySnapshot.docs
            .map((doc) => UserModel.fromMap(doc.id, doc.data()))
            .toList();
      }

      final lowercaseQuery = query.toLowerCase();

      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .where((user) {
        final firstName = user.firstName?.toLowerCase() ?? '';
        final lastName = user.lastName?.toLowerCase() ?? '';
        final fullName =
            '${user.firstName ?? ''} ${user.lastName ?? ''}'.toLowerCase();

        return firstName.contains(lowercaseQuery) ||
            lastName.contains(lowercaseQuery) ||
            fullName.contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      print('خطأ في البحث عن المنجمين: $e');
      return [];
    }
  }

  /// الحصول على المنجمين حسب معايير محددة (مثل برج معين)
  static Future<List<UserModel>> getAstrologersByFilter(
      {String? zodiacFilter}) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'astrologer')
          .where('astrologer_status', isEqualTo: 'approved');

      if (zodiacFilter != null && zodiacFilter.isNotEmpty) {
        // افتراض أن هناك حقل specializes_in_signs يحتوي على قائمة الأبراج التي يتخصص فيها المنجم
        query =
            query.where('specializes_in_signs', arrayContains: zodiacFilter);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) =>
              UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('خطأ في الحصول على المنجمين حسب المعايير: $e');
      return [];
    }
  }

  /// حفظ رمز جهاز المستخدم للإشعارات
  static Future<void> saveUserFCMToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcm_tokens': FieldValue.arrayUnion([token]),
      });
    } catch (e) {
      print('خطأ في حفظ رمز FCM للمستخدم: $e');
    }
  }

  /// إزالة رمز جهاز المستخدم للإشعارات
  static Future<void> removeUserFCMToken(String userId, String token) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcm_tokens': FieldValue.arrayRemove([token]),
      });
    } catch (e) {
      print('خطأ في إزالة رمز FCM للمستخدم: $e');
    }
  }
}
