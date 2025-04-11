import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const List<String> _allowedImageTypes = ['jpg', 'jpeg', 'png'];

  /// Validates if the file is an allowed image type
  static bool _isValidImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return _allowedImageTypes.contains(extension);
  }

  /// Uploads a profile image to Firebase Storage
  static Future<String?> uploadProfileImage(
    String userId,
    File imageFile,
  ) async {
    try {
      // فحص امتداد الملف أولاً
      final extension = imageFile.path.split('.').last.toLowerCase();
      if (!_allowedImageTypes.contains(extension)) {
        print('امتداد الملف غير مسموح به: $extension');
        throw FirebaseException(
          plugin: 'storage',
          message:
              'Invalid image type. Allowed types: ${_allowedImageTypes.join(', ')}',
        );
      }

      // التحقق من وجود الملف
      if (!imageFile.existsSync()) {
        print('ملف الصورة غير موجود: ${imageFile.path}');
        throw FirebaseException(
          plugin: 'storage',
          message: 'Image file does not exist',
        );
      }

      // إنشاء مرجع لموقع صورة الملف الشخصي
      final ref = _storage.ref().child('profile_images/$userId.$extension');

      // رفع الملف مع البيانات الوصفية
      final metadata = SettableMetadata(
        contentType: 'image/$extension',
        customMetadata: {'uploaded_by': userId},
      );

      print('بدء رفع الصورة: ${imageFile.path}');
      await ref.putFile(imageFile, metadata);
      print('تم رفع الصورة بنجاح');

      // الحصول على عنوان URL للتنزيل
      final downloadUrl = await ref.getDownloadURL();
      print('تم الحصول على رابط التنزيل: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('فشل في رفع صورة الملف الشخصي: $e');
      rethrow; // إعادة إلقاء الاستثناء ليتم التعامل معه في الطبقة العليا
    }
  }

  /// Deletes a profile image from Firebase Storage
  static Future<void> deleteProfileImage(String userId) async {
    try {
      // Try to delete images with all possible extensions
      for (final extension in _allowedImageTypes) {
        try {
          final ref = _storage.ref().child('profile_images/$userId.$extension');
          await ref.delete();
        } catch (e) {
          // Ignore errors if file with specific extension doesn't exist
          continue;
        }
      }
    } catch (e) {
      throw FirebaseException(
        plugin: 'storage',
        message: 'Failed to delete profile image: ${e.toString()}',
      );
    }
  }

  /// Gets the download URL of a profile image
  static Future<String?> getProfileImageUrl(String userId) async {
    try {
      // Try to get URL for each possible extension
      for (final extension in _allowedImageTypes) {
        try {
          final ref = _storage.ref().child('profile_images/$userId.$extension');
          return await ref.getDownloadURL();
        } catch (e) {
          continue;
        }
      }
      return null; // No image found with any extension
    } catch (e) {
      throw FirebaseException(
        plugin: 'storage',
        message: 'Failed to get profile image URL: ${e.toString()}',
      );
    }
  }
}
