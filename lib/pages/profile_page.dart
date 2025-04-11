import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../services/auth_service.dart';
import '../services/zodiac_service.dart';
import 'set_rates_page.dart';
import '../models/user_model.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../components/user_profile_image.dart';
import 'admin/admin_wallet_page.dart';
import '../theme.dart';
import 'admin_page.dart';
import 'admin_management_page.dart';
import 'astrologer_applications_page.dart';
import 'astrologer_rates_page.dart';
import 'approved_astrologers_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // حالة تحديث الصورة
  bool _isUpdatingImage = false;
  // سلسلة Base64 للصورة الجديدة
  String? _newProfileImageBase64;

  // التحقق من الهوية والصلاحيات
  Future<Map<String, bool>> _checkIdentityAndPermissions() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        return {'isCurrentUser': false, 'isAdmin': false};
      }
      
      final isCurrentUser = currentUser.uid == widget.userId;
      final isAdmin = await AuthService.isCurrentUserAdmin();
      
      print('Current user checking: ${currentUser.uid}');
      print('Profile user: ${widget.userId}');
      print('isCurrentUser: $isCurrentUser, isAdmin: $isAdmin');
      
      return {
        'isCurrentUser': isCurrentUser,
        'isAdmin': isAdmin,
      };
    } catch (e) {
      print('خطأ في التحقق من الهوية: $e');
      return {'isCurrentUser': false, 'isAdmin': false};
    }
  }

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickAndUploadImageBase64(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // تقليل جودة الصورة لتقليل حجم البيانات
        maxWidth: 800, // تقييد العرض الأقصى
        maxHeight: 800, // تقييد الارتفاع الأقصى
      );

      if (image == null) return;

      // تحديث حالة التحميل
      setState(() {
        _isUpdatingImage = true;
      });

      // عرض مؤشر التحميل
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('جاري معالجة الصورة...')));

      final String path = image.path;
      print('مسار الصورة المختارة: $path');

      // قراءة بيانات الصورة
      final Uint8List imageBytes = await image.readAsBytes();
      print('تم قراءة بيانات الصورة: ${imageBytes.length} بايت');

      if (imageBytes.isEmpty) {
        setState(() {
          _isUpdatingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل قراءة بيانات الصورة'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // التحقق من حجم الملف
      final int fileSize = imageBytes.length;
      const int maxSizeInBytes = 1 * 1024 * 1024; // 1 ميجابايت
      print('حجم الصورة: ${fileSize / 1024} كيلوبايت');

      if (fileSize > maxSizeInBytes) {
        setState(() {
          _isUpdatingImage = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حجم الصورة كبير جدًا. الحد الأقصى هو 1 ميجابايت'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // تحويل الصورة إلى سلسلة Base64
      final String base64Image = base64Encode(imageBytes);
      print('تم تحويل الصورة إلى Base64');

      // تحديث الصورة في Firestore
      final success = await AuthService.updateProfileImageBase64(base64Image);

      // تحديث حالة التطبيق
      setState(() {
        _isUpdatingImage = false;
        if (success) {
          _newProfileImageBase64 = base64Image;
        }
      });

      if (success) {
        // تحديث الشاشة فقط بدون إعادة بناء الصفحة بالكامل
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث صورة الملف الشخصي بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل تحديث صورة الملف الشخصي'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // تحديث حالة التطبيق في حالة الخطأ
      setState(() {
        _isUpdatingImage = false;
      });

      print('خطأ في اختيار وتحميل الصورة: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString().split(']').last.trim()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>> getUserProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();

    if (doc.exists) {
      return doc.data() as Map<String, dynamic>;
    } else {
      throw Exception('User not found');
    }
  }

  // دالة للحصول على أيقونة مناسبة لكل برج
  IconData _getZodiacIcon(String zodiacSign) {
    switch (zodiacSign.toLowerCase()) {
      case 'aries':
        return Icons.whatshot; // الحمل - رمز النار والحيوية
      case 'taurus':
        return Icons.filter_hdr; // الثور - رمز الجبال والثبات
      case 'gemini':
        return Icons.people_alt; // الجوزاء - رمز الازدواجية
      case 'cancer':
        return Icons.water_drop; // السرطان - رمز الماء
      case 'leo':
        return Icons.wb_sunny; // الأسد - رمز الشمس
      case 'virgo':
        return Icons.grass; // العذراء - رمز النقاء والطبيعة
      case 'libra':
        return Icons.balance; // الميزان - رمز التوازن
      case 'scorpio':
        return Icons.pest_control; // العقرب - رمز الحشرات
      case 'sagittarius':
        return Icons.assistant_direction; // القوس - رمز الاتجاه
      case 'capricorn':
        return Icons.landscape; // الجدي - رمز الأرض والجبال
      case 'aquarius':
        return Icons.water; // الدلو - رمز الماء المتدفق
      case 'pisces':
        return Icons.hub; // الحوت - رمز السباحة والاتصال
      default:
        return Icons.auto_awesome; // الافتراضي
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: getUserProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('حدث خطأ: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: Text('لا توجد بيانات'));
            }

            final userData = snapshot.data!;
            final firstName = userData['first_name'] ?? '';
            final lastName = userData['last_name'] ?? '';
            final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
                ? '$firstName $lastName'
                : userData['email'] ?? 'مستخدم';
            final profileImageUrl = userData['profile_image_url'];
            final zodiacSign = userData['zodiac_sign'] ?? 'غير محدد';
            final isAdmin = userData['is_admin'] ?? false;

            return FutureBuilder<Map<String, bool>>(
              future: _checkIdentityAndPermissions(),
              builder: (context, permissionsSnapshot) {
                if (permissionsSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final permissions = permissionsSnapshot.data ?? {'isCurrentUser': false, 'isAdmin': false};
                final isCurrentUser = permissions['isCurrentUser'] ?? false;
                final isViewerAdmin = permissions['isAdmin'] ?? false;
                
                print('Building UI with: isCurrentUser=$isCurrentUser, isViewerAdmin=$isViewerAdmin');
                
                // تغيير المنطق:
                // 1. إذا كان المستخدم هو نفس المستخدم الحالي (صاحب الملف) -> يمكنه رؤية نبذته وتعيين الأسعار
                // 2. إذا كان المشاهد مشرفًا وليس مالك الملف -> لا يمكنه رؤية النبذة ولا تعيين الأسعار
                // 3. إذا كان المشاهد مستخدمًا عاديًا (غير مشرف) -> يمكنه رؤية نبذة المستخدم الآخر
                final bool canViewAboutMe = isCurrentUser || !isViewerAdmin;
                final bool canViewSetPrices = isCurrentUser || !isViewerAdmin;
                
                // إضافة طباعة للتصحيح
                print('canViewAboutMe=$canViewAboutMe, canViewSetPrices=$canViewSetPrices');
                print('user_type=${userData['user_type']}, astrologer_status=${userData['astrologer_status']}');
                
                return CustomScrollView(
                  slivers: [
                    // شريط العنوان 
                    SliverAppBar(
                      title: const Text(
                        'الملف الشخصي',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      centerTitle: true,
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Theme.of(context).primaryColor,
                      floating: true,
                      snap: true,
                      actions: [
                        IconButton(
                          icon: const Icon(
                            Icons.logout,
                            color: Colors.white,
                          ),
                          tooltip: 'تسجيل الخروج',
                          onPressed: () async {
                            // عرض مربع حوار للتأكيد
                            bool confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('تسجيل الخروج'),
                                    content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('إلغاء'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text(
                                          'تسجيل الخروج',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;

                            if (confirm && context.mounted) {
                              try {
                                await AuthService.signOut();
                                if (context.mounted) {
                                  Navigator.of(context).pushReplacementNamed('/login');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'حدث خطأ أثناء تسجيل الخروج: ${e.toString()}',
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    
                    // محتوى الصفحة
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // بطاقة معلومات المستخدم الرئيسية
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Stack(
                                    alignment: Alignment.bottomRight,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: _newProfileImageBase64 != null
                                            ? CircleAvatar(
                                                radius: 60,
                                                backgroundImage: MemoryImage(
                                                  base64Decode(_newProfileImageBase64!),
                                                ),
                                              )
                                            : UserProfileImage(
                                                userId: widget.userId,
                                                radius: 60,
                                                placeholderIcon: SvgPicture.asset(
                                                  'assets/default_avatar.svg',
                                                  width: 120,
                                                  height: 120,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 5,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.camera_alt,
                                            color: Colors.white,
                                            size: 26,
                                          ),
                                          onPressed: () {
                                            _pickAndUploadImageBase64(context);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    fullName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 8),

                                  // عرض برج المستخدم فقط إذا كان مستخدمًا عاديًا وليس مشرفًا أو فلكيًا
                                  if (userData['user_type'] != 'astrologer' && !isAdmin)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 16.0),
                                      margin: const EdgeInsets.only(top: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getZodiacIcon(zodiacSign),
                                            color: AppTheme.getZodiacColor(zodiacSign),
                                            size: 28,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'البرج: ${ZodiacService.getArabicZodiacName(zodiacSign)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color:
                                                      AppTheme.getZodiacColor(zodiacSign),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // نبذة عني - تظهر فقط للفلكيين وإذا كان المستخدم هو نفسه أو ليس مشرف
                          Builder(
                            builder: (context) {
                              print('DEBUG: نبذة عني: user_type=${userData['user_type']}, canViewAboutMe=$canViewAboutMe');
                              
                              if (userData['user_type'] == 'astrologer' && canViewAboutMe) {
                                return Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.info_outline,
                                                    color: Colors.blue),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'نبذة عني',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: IconButton(
                                                icon: const Icon(Icons.edit,
                                                    color: Colors.blue),
                                                onPressed: () => _showEditAboutMeDialog(
                                                  context,
                                                  widget.userId,
                                                  userData['about_me'],
                                                ),
                                                tooltip: 'تعديل النبذة',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.blue.withOpacity(0.1),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            userData['about_me'] ??
                                                'لم تقم بإضافة نبذة عنك بعد...',
                                            style: Theme.of(context).textTheme.bodyLarge,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            },
                          ),

                          const SizedBox(height: 24),

                          // عرض زر تعيين الأسعار إذا كان المستخدم فلكيًا معتمدًا
                          // و إذا كان المستخدم هو نفسه أو ليس مشرف
                          Builder(
                            builder: (context) {
                              print('DEBUG: تعيين الأسعار: user_type=${userData['user_type']}, astrologer_status=${userData['astrologer_status']}, canViewSetPrices=$canViewSetPrices');
                              
                              if (userData['user_type'] == 'astrologer' &&
                                  userData['astrologer_status'] == 'approved' &&
                                  canViewSetPrices) {
                                return Column(
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.attach_money),
                                      label: const Text('تعيين أسعار الجلسات'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        minimumSize: const Size(double.infinity, 50),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 2,
                                      ),
                                      onPressed: () {
                                        final userModel = UserModel.fromMap(
                                          widget.userId,
                                          userData,
                                        );
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                SetRatesPage(currentUser: userModel),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            },
                          ),

                          // عرض القراءة اليومية فقط للمستخدمين العاديين (ليس فلكي وليس مشرف)
                          if (zodiacSign != 'غير محدد' &&
                              userData['user_type'] != 'astrologer' &&
                              !isAdmin)
                            FutureBuilder<Map<String, dynamic>>(
                              future: ZodiacService.getUserZodiacReading(widget.userId),
                              builder: (context, readingSnapshot) {
                                if (readingSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(20.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                if (readingSnapshot.hasError) {
                                  return Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text('لا يمكن تحميل القراءة اليومية'),
                                    ),
                                  );
                                }

                                final readingData = readingSnapshot.data ??
                                    {'reading': 'لا توجد قراءة متاحة'};
                                final reading =
                                    readingData['reading'] ?? 'لا توجد قراءة متاحة';

                                return Card(
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _getZodiacIcon(zodiacSign),
                                              color: AppTheme.getZodiacColor(zodiacSign),
                                              size: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'القراءة اليومية',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.getZodiacColor(
                                                        zodiacSign),
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            reading,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.copyWith(
                                                  height: 1.5,
                                                ),
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          else if (zodiacSign == 'غير محدد' &&
                              userData['user_type'] != 'astrologer' &&
                              !isAdmin)
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.info_outline,
                                            color: Colors.amber),
                                        const SizedBox(width: 8),
                                        Text(
                                          'القراءة اليومية',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.calendar_today,
                                              size: 32, color: Colors.amber),
                                          const SizedBox(height: 12),
                                          Text(
                                            'يرجى تحديث تاريخ الميلاد لعرض القراءة اليومية',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.edit),
                                            label: const Text('تحديث تاريخ الميلاد'),
                                            onPressed: () {
                                              _showUpdateBirthDateDialog(
                                                context,
                                                widget.userId,
                                                zodiacSign,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // إضافة قسم إدارة المحافظ للمشرفين
                          if (isAdmin) ...[
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.purple.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.admin_panel_settings,
                                          color: Colors.purple),
                                      const SizedBox(width: 8),
                                      Text(
                                        'أدوات المشرف',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.purple,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  
                                  // صفحة الإدارة
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.admin_panel_settings),
                                    label: const Text('صفحة الإدارة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AdminPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  
                                  // إدارة المستخدمين
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.people_alt),
                                    label: const Text('إدارة المستخدمين'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AdminManagementPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  
                                  // طلبات الفلكيين
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.star_border),
                                    label: const Text('طلبات الفلكيين'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AstrologerApplicationsPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  
                                  // إدارة أسعار الفلكيين
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.attach_money),
                                    label: const Text('إدارة أسعار الفلكيين'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AstrologerRatesPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  
                                  // الفلكيين المعتمدون
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.verified_user),
                                    label: const Text('الفلكيين المعتمدون'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ApprovedAstrologersPage(),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  
                                  // إدارة محافظ المستخدمين (الموجود مسبقاً)
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.account_balance_wallet),
                                    label: const Text('إدارة محافظ المستخدمين'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 2,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AdminWalletPage(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ]),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// استخراج دالة تحويل الصورة إلى Base64
String imageToBase64(File imageFile) {
  List<int> imageBytes = imageFile.readAsBytesSync();
  return base64Encode(imageBytes);
}

// دالة لصنع صورة من سلسلة Base64
Widget imageFromBase64(String base64String, {double radius = 60}) {
  try {
    return CircleAvatar(
      radius: radius,
      backgroundImage: MemoryImage(base64Decode(base64String)),
    );
  } catch (e) {
    print('خطأ في تحويل صورة Base64: $e');
    return CircleAvatar(
      radius: radius,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SvgPicture.asset(
          'assets/default_avatar.svg',
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

// دالة لعرض نافذة تعديل نص "نبذة عني"
Future<void> _showEditAboutMeDialog(
  BuildContext context,
  String userId,
  String? currentAboutMe,
) async {
  final TextEditingController aboutMeController = TextEditingController();
  aboutMeController.text = currentAboutMe ?? '';

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('تعديل نبذة عني'),
        content: TextField(
          controller: aboutMeController,
          decoration: const InputDecoration(
            hintText: 'اكتب نبذة تعريفية عن نفسك...',
          ),
          maxLines: 5,
          maxLength: 500,
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('إلغاء'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
          TextButton(
            child: const Text('حفظ'),
            onPressed: () async {
              // إظهار مؤشر التحميل
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('جاري الحفظ...')));

              // حفظ النبذة الجديدة
              bool success = await AuthService.updateAboutMe(
                userId,
                aboutMeController.text.trim(),
              );

              // إغلاق النافذة المنبثقة
              Navigator.of(dialogContext).pop();

              // عرض رسالة نجاح أو فشل
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'تم حفظ النبذة بنجاح' : 'فشل حفظ النبذة',
                  ),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
          ),
        ],
      );
    },
  );
}

// أضف هذه الدالة بعد _showEditAboutMeDialog
Future<void> _showUpdateBirthDateDialog(
  BuildContext context,
  String userId,
  String currentZodiacSign,
) async {
  final DateTime now = DateTime.now();
  final DateTime initialDate = DateTime(now.year - 18, now.month, now.day);
  final DateTime firstDate = DateTime(now.year - 100);
  final DateTime lastDate = DateTime(now.year - 12);

  try {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'اختر تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'تأكيد',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && context.mounted) {
      // عرض مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحديث تاريخ الميلاد...'),
              ],
            ),
          );
        },
      );

      // حفظ تاريخ الميلاد
      await ZodiacService.saveUserZodiac(userId, pickedDate);

      // إغلاق مؤشر التحميل وإظهار رسالة نجاح
      if (context.mounted) {
        Navigator.of(context).pop(); // إغلاق مؤشر التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث تاريخ الميلاد وبرجك الفلكي بنجاح'),
            backgroundColor: Colors.green,
          ),
        );

        // تحديث الصفحة من خلال إعادة بناء FutureBuilder
        if (context.mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ProfilePage(userId: userId),
            ),
          );
        }
      }
    }
  } catch (e) {
    // في حالة حدوث خطأ، التأكد من إغلاق مؤشر التحميل
    if (context.mounted) {
      Navigator.of(context).pop(); // إغلاق مؤشر التحميل إذا كان مفتوحًا
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
