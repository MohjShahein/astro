import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class UserProfileImage extends StatelessWidget {
  final String userId;
  final double radius;
  final bool showPlaceholder;
  final Widget? placeholderIcon;

  const UserProfileImage({
    super.key,
    required this.userId,
    this.radius = 40,
    this.showPlaceholder = true,
    this.placeholderIcon,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService.getUserProfileImageBase64(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // عرض دائرة تحميل أثناء جلب الصورة
          return CircleAvatar(
            radius: radius,
            child: const CircularProgressIndicator(),
          );
        }

        final base64Image = snapshot.data;

        if (base64Image != null && base64Image.isNotEmpty) {
          // استخدام صورة Base64 إذا كانت متوفرة
          return _imageFromBase64(base64Image);
        } else {
          // عرض الصورة الافتراضية
          return CircleAvatar(
            radius: radius,
            backgroundColor: Colors.grey.shade200,
            child:
                showPlaceholder
                    ? placeholderIcon ?? _defaultPlaceholder()
                    : const SizedBox(),
          );
        }
      },
    );
  }

  /// عرض الصورة من سلسلة Base64
  Widget _imageFromBase64(String base64String) {
    try {
      return CircleAvatar(
        radius: radius,
        backgroundImage: MemoryImage(base64Decode(base64String)),
      );
    } catch (e) {
      print('خطأ في تحويل صورة Base64: $e');
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child:
            showPlaceholder
                ? placeholderIcon ?? _defaultPlaceholder()
                : const SizedBox(),
      );
    }
  }

  /// صورة افتراضية للمستخدم
  Widget _defaultPlaceholder() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SvgPicture.asset(
        'assets/default_avatar.svg',
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
      ),
    );
  }
}
