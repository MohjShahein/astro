import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registers a new user with email and password
  static Future<(User?, String?)> registerUser(
    String email,
    String password, {
    String? firstName,
    String? lastName,
  }) async {
    try {
      // Check if Firebase Auth is properly initialized
      try {
        // Test if Firebase Auth is working by getting the current user (or any property)
        // This will throw an exception if Firebase Auth is not initialized
        _auth.app;
        print('Firebase Auth is properly initialized');
      } catch (e) {
        print('Firebase Auth initialization error: $e');
        return (null, 'خطأ في تهيئة Firebase Authentication');
      }

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = userCredential.user;
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'email': email,
            'first_name': firstName,
            'last_name': lastName,
            'created_at': FieldValue.serverTimestamp(),
            'profile_image_url': null,
            'is_admin': false,
            'user_type': 'normal',
            'astrologer_status': null,
            'about_me': null,
            'services': null,
          }, SetOptions(merge: true));
        } catch (e) {
          print('Error saving user data to Firestore: $e');
          // Continue with registration even if Firestore update fails
        }
      }
      return (user, null);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
          break;
        case 'invalid-email':
          errorMessage = 'البريد الإلكتروني غير صالح';
          break;
        case 'operation-not-allowed':
          errorMessage = 'تسجيل البريد الإلكتروني غير مفعل';
          break;
        case 'weak-password':
          errorMessage = 'كلمة المرور ضعيفة جداً';
          break;
        default:
          errorMessage = 'حدث خطأ أثناء التسجيل';
      }
      print("Error during registration: $e");
      return (null, errorMessage);
    } catch (e) {
      print("Error during registration: $e");
      return (null, 'حدث خطأ غير متوقع');
    }
  }

  /// Signs in an existing user with email and password
  static Future<(User?, String?)> signIn(String email, String password) async {
    try {
      // Check if Firebase Auth is properly initialized
      try {
        // Test if Firebase Auth is working by getting the current user (or any property)
        // This will throw an exception if Firebase Auth is not initialized
        _auth.app;
        print('Firebase Auth is properly initialized for sign in');
      } catch (e) {
        print('Firebase Auth initialization error: $e');
        return (null, 'خطأ في تهيئة Firebase Authentication');
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = userCredential.user;
      // We don't need to update the user document here as it would overwrite existing data
      // like zodiac sign information that was saved during registration
      return (user, null);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'لا يوجد مستخدم بهذا البريد الإلكتروني';
          break;
        case 'wrong-password':
          errorMessage = 'كلمة المرور غير صحيحة';
          break;
        case 'invalid-email':
          errorMessage = 'البريد الإلكتروني غير صالح';
          break;
        case 'user-disabled':
          errorMessage = 'تم تعطيل هذا الحساب';
          break;
        default:
          errorMessage = 'حدث خطأ أثناء تسجيل الدخول';
      }
      print("Error during sign in: $e");
      return (null, errorMessage);
    } catch (e) {
      print("Error during sign in: $e");
      return (null, 'حدث خطأ غير متوقع');
    }
  }

  /// Signs out the current user
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("Error during sign out: $e");
    }
  }

  /// Gets the current authenticated user
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Updates user's profile image
  static Future<bool> updateProfileImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        File? processedImage = imageFile;

        // تحديث بيانات الصورة في Firestore مباشرة
        await _firestore.collection('users').doc(user.uid).update({
          'profile_image_base64': null,
          'profile_image_url': null, // تعيين الرابط القديم كقيمة فارغة
          'last_updated': FieldValue.serverTimestamp(),
        });

        print('تم تحديث بيانات الصورة في Firestore بنجاح');
        return true;
      } else {
        print('خطأ: لا يوجد مستخدم قيد تسجيل الدخول');
        return false;
      }
    } catch (e) {
      print('خطأ في تحديث صورة الملف الشخصي: $e');
      final errorMessage = e.toString();
      print('رسالة الخطأ: $errorMessage');
      return false;
    }
  }

  /// Updates user's profile image with Base64 string
  static Future<bool> updateProfileImageBase64(String base64Image) async {
    final user = getCurrentUser();
    if (user == null) {
      print('خطأ: لا يوجد مستخدم قيد تسجيل الدخول');
      return false;
    }

    try {
      print('جاري تحديث صورة الملف الشخصي للمستخدم: ${user.uid}');

      // التحقق من أن المدخلات صالحة
      if (base64Image.isEmpty) {
        print('خطأ: بيانات Base64 للصورة فارغة');
        return false;
      }

      // تحديث بيانات الصورة في Firestore مباشرة
      await _firestore.collection('users').doc(user.uid).update({
        'profile_image_base64': base64Image,
        'profile_image_url': null, // تعيين الرابط القديم كقيمة فارغة
        'last_updated': FieldValue.serverTimestamp(),
      });

      print('تم تحديث بيانات الصورة في Firestore بنجاح');
      return true;
    } catch (e) {
      print('خطأ في تحديث صورة الملف الشخصي: $e');
      final errorMessage = e.toString();
      print('رسالة الخطأ: $errorMessage');
      return false;
    }
  }

  /// الحصول على صورة الملف الشخصي بتنسيق Base64
  static Future<String?> getProfileImageBase64() async {
    final user = getCurrentUser();
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['profile_image_base64'] as String?;
    } catch (e) {
      print('خطأ في الحصول على صورة الملف الشخصي: $e');
      return null;
    }
  }

  /// الحصول على صورة الملف الشخصي بتنسيق Base64 لمستخدم معين
  static Future<String?> getUserProfileImageBase64(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data()?['profile_image_base64'] as String?;
    } catch (e) {
      print('خطأ في الحصول على صورة الملف الشخصي للمستخدم: $e');
      return null;
    }
  }

  /// Checks if the current user is an admin
  static Future<bool> isCurrentUserAdmin() async {
    try {
      final user = getCurrentUser();
      if (user == null) {
        print('isCurrentUserAdmin: No user is currently logged in');
        return false;
      }

      print(
        'isCurrentUserAdmin: Checking admin status for user ID: ${user.uid}',
      );

      try {
        print('isCurrentUserAdmin: Fetching user document from Firestore');
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          print(
            'isCurrentUserAdmin: User document does not exist in Firestore',
          );
          return false;
        }

        final userData = doc.data();
        if (userData == null) {
          print('isCurrentUserAdmin: User data is null');
          return false;
        }

        final bool isAdmin = userData['is_admin'] == true;

        print('isCurrentUserAdmin: User admin status: $isAdmin');
        return isAdmin;
      } catch (e) {
        print('Error checking admin status from Firestore: $e');
        return false;
      }
    } catch (e) {
      print('Unexpected error in isCurrentUserAdmin: $e');
      return false;
    }
  }

  /// Sets admin status for a specific user
  static Future<bool> setUserAdminStatus(String userId, bool isAdmin) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'is_admin': isAdmin,
      });
      return true;
    } catch (e) {
      print('Error setting admin status: $e');
      return false;
    }
  }

  /// Stream of auth state changes
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Get user data as UserModel
  static Future<UserModel?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;

      return UserModel.fromMap(userId, doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  /// Apply to become an astrologer
  static Future<bool> applyForAstrologer(
    String userId,
    String aboutMe,
    List<String> services,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'user_type': 'astrologer',
        'astrologer_status': 'pending',
        'about_me': aboutMe,
        'services': services,
      });
      return true;
    } catch (e) {
      print('Error applying for astrologer: $e');
      return false;
    }
  }

  /// Update astrologer profile
  static Future<bool> updateAstrologerProfile(
    String userId,
    String aboutMe,
    List<String> services,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'about_me': aboutMe,
        'services': services,
      });
      return true;
    } catch (e) {
      print('Error updating astrologer profile: $e');
      return false;
    }
  }

  /// التحقق من حالة الفلكي
  static Future<Map<String, dynamic>> getAstrologerStatus(
    String astrologerId,
  ) async {
    try {
      // التحقق من وجود الفلكي في جدول المستخدمين
      final userDoc =
          await _firestore.collection('users').doc(astrologerId).get();

      if (!userDoc.exists) {
        return {
          'exists': false,
          'message': 'الفلكي غير موجود في قاعدة البيانات',
        };
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final userType = userData['user_type'];

      if (userType != 'astrologer') {
        return {'exists': false, 'message': 'المستخدم ليس فلكياً'};
      }

      // التحقق من حالة الفلكي
      final astrologerStatus = userData['astrologer_status'];

      if (astrologerStatus == null) {
        return {'exists': false, 'message': 'حالة الفلكي غير محددة'};
      }

      // التحقق من وجود الفلكي في قائمة الفلكيين المعتمدين
      final isApproved = await isApprovedAstrologer(astrologerId);

      return {
        'exists': true,
        'status': astrologerStatus,
        'is_approved': isApproved,
        'message': isApproved ? 'الفلكي معتمد' : 'الفلكي غير معتمد',
      };
    } catch (e) {
      print('Error checking astrologer status: $e');
      return {
        'exists': false,
        'message': 'حدث خطأ أثناء التحقق من حالة الفلكي',
      };
    }
  }

  /// تحديث حالة الفلكي
  static Future<bool> updateAstrologerStatus(
    String astrologerId,
    String status,
    String? reason,
  ) async {
    try {
      // التحقق من وجود الفلكي
      final userDoc =
          await _firestore.collection('users').doc(astrologerId).get();

      if (!userDoc.exists) {
        throw 'الفلكي غير موجود';
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['user_type'] != 'astrologer') {
        throw 'المستخدم ليس فلكياً';
      }

      // تحديث حالة الفلكي في جدول المستخدمين
      await _firestore.collection('users').doc(astrologerId).update({
        'astrologer_status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // إضافة أو إزالة الفلكي من قائمة الفلكيين المعتمدين
      if (status == 'approved') {
        await _firestore
            .collection('approved_astrologers')
            .doc(astrologerId)
            .set({
          'approved_at': FieldValue.serverTimestamp(),
          'approved_by': getCurrentUser()?.uid,
        });
      } else {
        await _firestore
            .collection('approved_astrologers')
            .doc(astrologerId)
            .delete();
      }

      // إضافة سجل في جدول سجلات الحالة
      await _firestore.collection('status_logs').add({
        'astrologer_id': astrologerId,
        'status': status,
        'reason': reason,
        'updated_by': getCurrentUser()?.uid,
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error updating astrologer status: $e');
      rethrow;
    }
  }

  /// تحديث نوع المستخدم (عادي، فلكي)
  static Future<bool> updateUserType(String userId, String userType) async {
    try {
      if (!['normal', 'astrologer'].contains(userType)) {
        return false;
      }

      // التحقق من صلاحيات المستخدم الحالي
      final currentUser = getCurrentUser();
      if (currentUser == null) return false;

      // التحقق من أن المستخدم الحالي هو المسؤول
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) return false;

      // التحقق من وجود المستخدم المراد تحديثه
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      // تحديث نوع المستخدم
      await _firestore.collection('users').doc(userId).update({
        'user_type': userType,
        // إذا تم تغيير نوع المستخدم إلى عادي، قم بإعادة تعيين حالة الفلكي
        'astrologer_status': userType == 'normal' ? null : 'pending',
      });

      // إذا تم تغيير نوع المستخدم إلى عادي، قم بحذفه من قائمة الفلكيين المعتمدين
      if (userType == 'normal') {
        await _firestore
            .collection('approved_astrologers')
            .doc(userId)
            .delete();
      }

      return true;
    } catch (e) {
      print('Error updating user type: $e');
      return false;
    }
  }

  /// Get all astrologer applications
  static Future<List<UserModel>> getAstrologerApplications() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'astrologer')
          .where('astrologer_status', isEqualTo: 'pending')
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error getting astrologer applications: $e');
      return [];
    }
  }

  /// Get all approved astrologers
  static Future<List<UserModel>> getApprovedAstrologers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('user_type', isEqualTo: 'astrologer')
          .where('astrologer_status', isEqualTo: 'approved')
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('Error getting approved astrologers: $e');
      return [];
    }
  }

  /// التحقق من وجود الفلكي في قائمة الفلكيين المعتمدين
  static Future<bool> isApprovedAstrologer(String astrologerId) async {
    try {
      final approvedDoc = await _firestore
          .collection('approved_astrologers')
          .doc(astrologerId)
          .get();

      return approvedDoc.exists;
    } catch (e) {
      print('Error checking approved astrologer: $e');
      return false;
    }
  }

  /// إضافة فلكي إلى قائمة الفلكيين المعتمدين
  static Future<bool> addApprovedAstrologer(String astrologerId) async {
    try {
      // التحقق أولا من أن المستخدم فلكي معتمد في جدول المستخدمين
      final userDoc =
          await _firestore.collection('users').doc(astrologerId).get();

      if (!userDoc.exists) {
        throw 'المستخدم غير موجود';
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      if (userData['user_type'] != 'astrologer') {
        throw 'المستخدم ليس فلكياً';
      }

      if (userData['astrologer_status'] != 'approved') {
        throw 'الفلكي غير معتمد';
      }

      // إضافة الفلكي إلى قائمة الفلكيين المعتمدين
      await _firestore
          .collection('approved_astrologers')
          .doc(astrologerId)
          .set({
        'approved_at': FieldValue.serverTimestamp(),
        'approved_by': getCurrentUser()?.uid,
      });

      return true;
    } catch (e) {
      print('Error adding approved astrologer: $e');
      return false;
    }
  }

  /// حذف فلكي من قائمة الفلكيين المعتمدين
  static Future<bool> removeApprovedAstrologer(String astrologerId) async {
    try {
      await _firestore
          .collection('approved_astrologers')
          .doc(astrologerId)
          .delete();

      // تحديث حالة الفلكي في جدول المستخدمين (اختياري)
      await _firestore.collection('users').doc(astrologerId).update({
        'astrologer_status': 'pending',
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error removing approved astrologer: $e');
      return false;
    }
  }

  /// تحديث نص "نبذة عني" للمستخدم
  static Future<bool> updateAboutMe(String userId, String aboutMe) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'about_me': aboutMe,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('تم تحديث نبذة عني بنجاح للمستخدم: $userId');
      return true;
    } catch (e) {
      print('خطأ في تحديث نبذة عني: $e');
      return false;
    }
  }

  /// الحصول على قائمة جميع المستخدمين للمشرفين
  static Future<List<UserModel>> getAllUsers({int limit = 50}) async {
    try {
      // التحقق من صلاحيات المشرف
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('محاولة غير مصرح بها للوصول لقائمة المستخدمين');
        return [];
      }

      final snapshot = await _firestore.collection('users').limit(limit).get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      print('خطأ في الحصول على قائمة المستخدمين: $e');
      return [];
    }
  }

  /// البحث عن مستخدمين بناءً على الاسم أو البريد الإلكتروني
  static Future<List<UserModel>> searchUsers(String query,
      {int limit = 20}) async {
    try {
      // التحقق من صلاحيات المشرف
      final isAdmin = await isCurrentUserAdmin();
      if (!isAdmin) {
        print('محاولة غير مصرح بها للبحث عن المستخدمين');
        return [];
      }

      // لا يمكن البحث المباشر على النص في Firestore، لذا سنحصل على قائمة المستخدمين ونصفيها
      final snapshot = await _firestore
          .collection('users')
          .limit(100) // نحصل على عدد أكبر ثم نصفي محليًا
          .get();

      // تصفية النتائج محليًا
      final List<UserModel> allUsers = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();

      // البحث في الأسماء والبريد الإلكتروني
      final lowercaseQuery = query.toLowerCase();

      return allUsers
          .where((user) =>
              (user.email.toLowerCase().contains(lowercaseQuery)) ||
              (user.firstName?.toLowerCase().contains(lowercaseQuery) ??
                  false) ||
              (user.lastName?.toLowerCase().contains(lowercaseQuery) ?? false))
          .take(limit)
          .toList();
    } catch (e) {
      print('خطأ في البحث عن المستخدمين: $e');
      return [];
    }
  }
}
