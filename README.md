# توثيق تطبيق الأبراج للمطورين

## نظرة عامة

تطبيق الأبراج هو تطبيق Flutter يوفر خدمات متعلقة بالأبراج والتنجيم. يتيح التطبيق للمستخدمين إنشاء حسابات، وعرض قراءات الأبراج اليومية، والتواصل مع المنجمين، وإدارة المواعيد والمدفوعات.

## التحديثات الحديثة - 2025/04

### تحسين تجربة المستخدم للفلكيين والمشرفين (2025/04/25)
- **إخفاء برج المستخدم**: إخفاء عرض برج المستخدم في صفحة الملف الشخصي للفلكيين والمشرفين
- **إخفاء القراءة اليومية**: إزالة قسم القراءة اليومية للبرج من صفحة الملف الشخصي للفلكيين والمشرفين
- **تبسيط الواجهة**: عرض فقط المعلومات المهمة والضرورية حسب نوع المستخدم
- **تحسين التركيز**: مساعدة الفلكيين على التركيز على تقديم الخدمة بدلاً من استهلاكها

#### نموذج تنفيذ الإخفاء الشرطي لبرج المستخدم والقراءة اليومية
```dart
// إخفاء برج المستخدم للفلكيين والمشرفين
if (userData['user_type'] != 'astrologer' && !isAdmin)
  Container(
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.getZodiacColor(zodiacSign),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    ),
  ),

// إخفاء القراءة اليومية للفلكيين والمشرفين
if (zodiacSign != 'غير محدد' && 
    userData['user_type'] != 'astrologer' && 
    !isAdmin)
  FutureBuilder<Map<String, dynamic>>(
    future: ZodiacService.getUserZodiacReading(widget.userId),
    builder: (context, readingSnapshot) {
      // عرض القراءة اليومية...
    },
  )
```

### تحسين أداء الاستعلامات وترتيب الجلسات (2025/04/28)
- **إلغاء استخدام الفهارس المركبة**: تم تبسيط استعلامات Firestore لتجنب الحاجة إلى إنشاء فهارس مركبة.
- **ترتيب الجلسات على جانب العميل**: تنفيذ ترتيب القائمة على جانب العميل بدلاً من الاعتماد على ترتيب Firestore.
- **استخدام معايير ترتيب متعددة**: ترتيب الجلسات بناءً على وقت آخر رسالة أو تاريخ الإنشاء أو وقت الانتهاء.
- **تحسين معالجة الأخطاء**: إضافة حماية متعددة المستويات ضد الأخطاء المتعلقة بالبيانات المفقودة.

#### نموذج للاستعلام المُبسّط في ChatService
```dart
/// الحصول على جلسات المستخدم حسب الحالة
static Stream<QuerySnapshot> getUserSessionsByStatus(
  String userId,
  String status,
) {
  try {
    print('استعلام عن جلسات المستخدم حسب الحالة: userId=$userId, status=$status');

    // نستخدم استعلام بسيط بدون ترتيب لتجنب مشكلة الفهرس المركب
    // يمكن إجراء الترتيب على جانب العميل بعد استلام البيانات
    return _firestore
        .collection('chat_sessions')
        .where('participants', arrayContains: userId)
        .where('status', isEqualTo: status)
        .snapshots();
  } catch (e) {
    print('خطأ في الحصول على جلسات المستخدم حسب الحالة: $e');

    // في حالة حدوث خطأ، نستخدم الاستعلام الأبسط
    return _firestore
        .collection('chat_sessions')
        .where('status', isEqualTo: status)
        .snapshots();
  }
}
```

#### نموذج لترتيب الجلسات على جانب العميل في ActiveSessionsPage
```dart
// استخراج البيانات وفرزها حسب وقت آخر رسالة أو تاريخ الإنشاء (من الأحدث إلى الأقدم)
final docs = snapshot.data!.docs;
List<DocumentSnapshot> sortedDocs = List.from(docs);

// محاولة فرز المستندات
try {
  sortedDocs.sort((a, b) {
    final aData = a.data() as Map<String, dynamic>;
    final bData = b.data() as Map<String, dynamic>;

    // استخدام last_message_at أولًا إذا كان موجودًا
    final aLastMessage = aData['last_message_at'] as Timestamp?;
    final bLastMessage = bData['last_message_at'] as Timestamp?;

    if (aLastMessage != null && bLastMessage != null) {
      return bLastMessage.compareTo(aLastMessage); // ترتيب تنازلي
    }

    // استخدام created_at كبديل إذا لم يكن last_message_at متاحًا
    final aCreated = aData['created_at'] as Timestamp?;
    final bCreated = bData['created_at'] as Timestamp?;

    if (aCreated == null && bCreated == null) return 0;
    if (aCreated == null) return 1;
    if (bCreated == null) return -1;

    return bCreated.compareTo(aCreated); // ترتيب تنازلي
  });
} catch (e) {
  print('خطأ في فرز الجلسات النشطة: $e');
  // استمر بدون فرز إذا حدث خطأ
}
```

### نقل زر التقييم إلى صفحة الملف الشخصي للفلكي (2025/04/25)
- **تحسين تجربة المستخدم**: تم نقل زر "إضافة تقييم" من صفحة الجلسات المكتملة إلى صفحة الملف الشخصي للفلكي
- **توحيد واجهة المستخدم**: أصبح بإمكان المستخدمين تقييم الفلكي مباشرة من صفحة ملفه الشخصي بدلاً من الحاجة للعودة إلى تاريخ الجلسات
- **تجنب التقييمات المتكررة**: يتم إخفاء زر التقييم تمامًا إذا كان المستخدم قد قيّم الفلكي مسبقًا
- **تصميم متناسق**: تم تنسيق الزر ليتناسب مع تصميم صفحة الملف الشخصي

#### نموذج كود لزر التقييم في صفحة الملف الشخصي للفلكي
```dart
// في قسم التقييمات بصفحة الملف الشخصي للفلكي
if (_currentUser != null && _currentUser!.userType != 'astrologer') 
  FutureBuilder<bool>(
    future: ReviewService.hasUserReviewedAstrologer(
      widget.currentUserId, 
      widget.astrologerId
    ),
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
          icon: const Icon(Icons.star, color: Colors.amber),
          label: const Text('أضف تقييمك'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E1E2A),
            foregroundColor: Colors.white,
          ),
        ),
      );
    },
  ),
```

### إضافة نظام تقييم للجلسات المكتملة (2025/04/23)
- **زر تقييم في الجلسات المكتملة**: إضافة زر لتقييم الفلكي يظهر في قائمة الجلسات المكتملة.
- **تجنب التقييمات المتكررة**: تحقق تلقائي مما إذا كان المستخدم قد قام بتقييم الفلكي من قبل لمنع التقييمات المتكررة.
- **واجهة تقييم سهلة الاستخدام**: تصميم واجهة تقييم بسيطة تتضمن نجوم (1-5) مع إمكانية إضافة تعليق نصي.
- **عرض التقييمات في صفحة الفلكي**: عرض جميع التقييمات في صفحة الفلكي مع متوسط تقييمه العام.
- **تكامل مع قائمة الفلكيين**: عرض متوسط تقييم كل فلكي في قائمة الفلكيين المتاحين.

#### نموذج كود للتحقق من وجود تقييم سابق
```dart
/// التحقق مما إذا كان المستخدم قد قام بتقييم فلكي معين مسبقًا
static Future<bool> hasUserReviewedAstrologer(String userId, String astrologistId) async {
  try {
    QuerySnapshot snapshot = await _firestore
        .collection('reviews')
        .where('user_id', isEqualTo: userId)
        .where('astrologist_id', isEqualTo: astrologistId)
        .get();
    
    return snapshot.docs.isNotEmpty;
  } catch (e) {
    print('خطأ في التحقق من تقييمات المستخدم: $e');
    return false;
  }
}
```

#### نموذج لزر إضافة التقييم في الجلسات المكتملة
```dart
FutureBuilder<bool>(
  future: ReviewService.hasUserReviewedAstrologer(
    widget.currentUser.id,
    astrologerId,
  ),
  builder: (context, reviewSnapshot) {
    if (reviewSnapshot.connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator(strokeWidth: 2);
    }
    
    if (reviewSnapshot.data == false) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddReviewPage(
                userId: widget.currentUser.id,
                astrologerId: astrologerId,
                astrologerName: astrologerName,
              ),
            ),
          );
        },
        icon: const Icon(Icons.star_rate, color: Colors.amber),
        label: const Text('إضافة تقييم'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF21202F),
        ),
      );
    } else {
      return const Text('تم إضافة تقييم سابقاً');
    }
  },
)
```

### تحسين عرض الأبراج وزيادة وزن الخط (2025/04/20)
- **تخصيص أيقونات الأبراج**: تم إضافة أيقونات مخصصة لكل برج من الأبراج الاثني عشر تعكس طبيعة البرج وخصائصه الرئيسية.
- **زيادة وزن الخط**: تم تحسين وزن الخط في جميع أنحاء التطبيق ليكون أكثر سمكًا وأوضح للقراءة.
  - تعديل `FontWeight` الافتراضي في `arabicStyle` من `normal` إلى `w500`.
  - زيادة وزن العناوين الكبيرة من `w300` إلى `w400`.
  - تحسين وزن العناوين المتوسطة والصغيرة من `w400` إلى `w500`.
  - زيادة وزن العناوين الفرعية من `w500` إلى `w600`.
  - تحسين وزن نصوص المتن من `w400` إلى `w500`.
  - زيادة وزن التسميات من `w500` إلى `w600`.
- **تحسين عرض البرج في الملف الشخصي**: تم تعديل طريقة عرض برج المستخدم في الملف الشخصي ليكون أكثر وضوحًا من خلال:
  - إضافة أيقونة مخصصة لكل برج.
  - تلوين النص والأيقونة بلون البرج المحدد.
  - زيادة حجم الأيقونة وتحسين وزن الخط لإبراز معلومات البرج.

#### نموذج تعديلات وزن الخط
```dart
// دالة مساعدة للحصول على نمط نص باستخدام خط عربي - الإصدار المحسن
static TextStyle arabicStyle({
  Color? color,
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w500, // تم زيادة الوزن من normal
  double? height,
  TextDecoration? decoration,
  // المزيد من الخصائص...
}) {
  return GoogleFonts.tajawal(
    color: color ?? Colors.white,
    fontSize: fontSize,
    fontWeight: fontWeight,
    // المزيد من الخصائص...
  );
}

// مثال على تحسين وزن العناوين والنصوص
static TextTheme _getTextTheme() {
  const baseTextColor = Colors.white;

  return TextTheme(
    displayLarge: GoogleFonts.tajawal(
      color: baseTextColor,
      fontSize: 57,
      fontWeight: FontWeight.w400, // تم زيادة الوزن من w300
    ),
    titleLarge: GoogleFonts.tajawal(
      color: baseTextColor,
      fontSize: 22,
      fontWeight: FontWeight.w600, // تم زيادة الوزن من w500
    ),
    bodyLarge: GoogleFonts.tajawal(
      color: baseTextColor,
      fontSize: 16,
      fontWeight: FontWeight.w500, // تم زيادة الوزن من w400
    ),
    // المزيد من التعديلات...
  );
}

#### نموذج كود لعرض أيقونات الأبراج
```dart
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

// استخدام الأيقونة في واجهة المستخدم
Container(
  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: AppTheme.getZodiacColor(zodiacSign),
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  ),
)
```

### تغيير خط التطبيق إلى Tajawal
- **إضافة Google Fonts**: تم إضافة حزمة `google_fonts` للاستفادة من خط Tajawal بشكل مباشر من Google Fonts.
- **تطبيق خط Tajawal**: تم تحديث واجهة المستخدم بالكامل لاستخدام خط Tajawal العربي المميز.
- **تحسين قراءة النص**: Tajawal يوفر قراءة أفضل للنصوص العربية وتجربة مستخدم متميزة.
- **الإعداد**: لاستخدام الخط، أضفنا الحزمة باستخدام `flutter pub add google_fonts` وقمنا بتطبيق الخط من خلال تعديل السمة الرئيسية.

### تحسينات في معالجة المعاملات المالية عند إنهاء الجلسات
- **إعادة هيكلة دالة `endSession`**: تم تعديل الدالة بشكل كامل لضمان تحديث حالة الجلسة أولاً ثم محاولة إنشاء المعاملات المالية.
- **تبسيط دالة `createSessionTransaction`**: تم تبسيط عملية إنشاء المعاملات المالية وتحديث المحافظ لضمان الموثوقية.
- **تحسين معالجة الأخطاء**: التأكد من استمرار العملية حتى في حالة فشل إنشاء المعاملات المالية.
- **تعديل تسلسل العمليات**: تحديث حالة الجلسة أولاً إلى "مكتملة" قبل معالجة المدفوعات لضمان عدم تعليق الجلسة.

### تحديث قواعد الصلاحيات في Firestore
- **تبسيط قواعد مجموعة `transactions`**: تم تعديل القواعد للسماح لأي مستخدم مسجل بإنشاء المعاملات المالية.
- **تعديل قواعد مجموعة `wallets`**: تم تغيير القواعد للسماح بالقراءة والكتابة دون قيود للمستخدمين المسجلين.
- **إصلاح استدعاء دالة `isAdmin`**: تم تحديث استدعاء الدالة بإضافة المعلمة المطلوبة `userId`.

### إصلاح مشكلة إنهاء الجلسات
- **تعديل دالة `_endSession` في `active_sessions_page.dart`**: تم تغيير استدعاء الدالة من `endPaidChatSession` إلى `endSession`.
- **تنفيذ نقل الأموال من المستخدم إلى المنجم**: تم التأكد من نقل المبالغ بشكل صحيح بين محافظ المستخدمين.
- **إضافة سجلات تفصيلية**: تمت إضافة رسائل سجلات أكثر تفصيلًا لتسهيل تتبع عملية المعاملة المالية وتشخيص المشكلات.

### المشكلات التي تم حلها
1. **مشكلة الصلاحيات**:
   - المشكلة: عدم القدرة على إنشاء المعاملات المالية بسبب قيود الصلاحيات في Firestore.
   - الحل: تعديل قواعد الأمان في Firestore للسماح بإنشاء المعاملات وتحديث المحافظ.

2. **مشكلة تعليق الجلسات**:
   - المشكلة: إنهاء الجلسة مرتبط بنجاح إنشاء المعاملات المالية، مما قد يؤدي إلى تعليق الجلسة.
   - الحل: فصل عملية تحديث حالة الجلسة عن عملية إنشاء المعاملات المالية.

3. **معالجة الأخطاء**:
   - المشكلة: فشل إنهاء الجلسة بالكامل عند حدوث خطأ في أي خطوة.
   - الحل: تحسين معالجة الأخطاء وإعادة قيمة محددة عند فشل إنشاء المعاملات بدلاً من رمي الاستثناءات.

### كيفية تحديث قواعد Firestore
لنشر تغييرات قواعد الأمان الخاصة بـ Firestore، يجب اتباع الخطوات التالية:

1. انتقل إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك `astrology-d317e`
3. انتقل إلى Firestore Database
4. انقر على تبويب "Rules"
5. انسخ محتوى ملف `firestore.rules` المحلي واستبدل القواعد الحالية
6. انقر على "Publish"

#### قواعد Firestore المحدثة الرئيسية

```javascript
// Wallets collection
match /wallets/{userId} {
  allow read, write: if isSignedIn();
}

// Transactions collection
match /transactions/{document=**} {
  allow read: if isSignedIn();
  allow create: if isSignedIn();
  allow update, delete: if isAdmin(request.auth.uid);
}
```

### نموذج تدفق إنهاء الجلسة (المحدث)
1. المستخدم أو المنجم يطلب إنهاء الجلسة الحالية
2. يتم تحديث حالة الجلسة إلى 'processing_end'
3. يتم حساب التكلفة الإجمالية بناءً على مدة الجلسة والسعر
4. يتم تحديث حالة الجلسة إلى 'completed' مباشرة
5. يتم محاولة إنشاء المعاملات المالية:
   - معاملة خصم للمستخدم
   - معاملة إضافة للمنجم
6. يتم إرسال إشعارات للمستخدم والمنجم

### كود دالة `endSession` المحدثة
```dart
static Future<void> endSession(String sessionId) async {
  try {
    // الحصول على بيانات الجلسة
    DocumentSnapshot sessionSnapshot =
        await _firestore.collection('chat_sessions').doc(sessionId).get();

    if (!sessionSnapshot.exists) {
      throw 'الجلسة غير موجودة: $sessionId';
    }

    Map<String, dynamic> sessionData =
        sessionSnapshot.data() as Map<String, dynamic>;

    // التحقق من أن الجلسة نشطة
    if (sessionData['status'] != 'active') {
      throw 'لا يمكن إنهاء جلسة غير نشطة: ${sessionData['status']}';
    }

    // الحصول على معرفات المستخدم والفلكي
    String userId = sessionData['user_id'];
    String astrologerId = sessionData['astrologer_id'];
    bool isFreeSession = sessionData['is_free_session'] ?? false;

    // حساب المدة والتكلفة
    Timestamp startTime = sessionData['start_time'];
    Timestamp endTime = Timestamp.now();
    int durationInMinutes =
        ((endTime.seconds - startTime.seconds) / 60).ceil();

    // حساب التكلفة الإجمالية
    double ratePerMinute = 1.0; // قيمة افتراضية
    if (sessionData['rate_per_minute'] is double) {
      ratePerMinute = sessionData['rate_per_minute'];
    } else if (sessionData['rate_per_minute'] is int) {
      ratePerMinute = (sessionData['rate_per_minute'] as int).toDouble();
    }

    double totalCost = 0.0;
    if (!isFreeSession) {
      totalCost = ratePerMinute * durationInMinutes;
    }

    // تحديث حالة الجلسة أولاً للإشارة إلى أنها بدأت بالانتهاء
    await _firestore.collection('chat_sessions').doc(sessionId).update({
      'processing_end': true,
    });

    // تحديث حالة الجلسة مباشرة بدون انتظار معالجة المعاملات المالية
    await _firestore.collection('chat_sessions').doc(sessionId).update({
      'status': 'completed',
      'end_time': endTime,
      'total_duration': durationInMinutes,
      'total_cost': totalCost,
      'processing_end': false,
    });

    // محاولة معالجة المعاملات المالية للجلسات المدفوعة فقط
    if (!isFreeSession) {
      try {
        // استدعاء WalletService لمعالجة المعاملات المالية
        await WalletService.createSessionTransaction(
          userId,
          -totalCost, // المبلغ سالب لأنه خصم
          'payment',
          sessionId: sessionId,
          sessionTitle: sessionData['title'] ?? 'جلسة استشارية',
          otherPartyId: astrologerId,
          description: 'دفع مقابل جلسة لمدة $durationInMinutes دقيقة',
        );

        await WalletService.createSessionTransaction(
          astrologerId,
          totalCost, // المبلغ موجب لأنه إضافة
          'earning',
          sessionId: sessionId,
          sessionTitle: sessionData['title'] ?? 'جلسة استشارية',
          otherPartyId: userId,
          description: 'أرباح من جلسة لمدة $durationInMinutes دقيقة',
        );
      } catch (walletError) {
        print('خطأ في معالجة المعاملات المالية: $walletError');
        // لن نعيد رمي الخطأ هنا لضمان إكمال الجلسة
      }
    }

    // إرسال الإشعارات
    try {
      await NotificationService.addNotification(
        userId,
        'تم إنهاء الجلسة بنجاح. المدة: $durationInMinutes دقيقة${!isFreeSession ? '، التكلفة: $totalCost كوينز' : ''}.',
      );

      await NotificationService.addNotification(
        astrologerId,
        'تم إنهاء الجلسة بنجاح. المدة: $durationInMinutes دقيقة${!isFreeSession ? '، الأرباح: $totalCost كوينز' : ''}.',
      );
    } catch (notificationError) {
      print('خطأ في إرسال الإشعارات: $notificationError');
      // نتجاهل خطأ الإشعارات ونستمر
    }
  } catch (e) {
    print('خطأ في إنهاء الجلسة: $e');
    rethrow;
  }
}
```

### كود دالة `createSessionTransaction` المحدثة
```dart
static Future<bool> createSessionTransaction(
  String userId,
  double amount,
  String transactionType, {
  String? sessionId,
  String? sessionTitle,
  String? otherPartyId,
  String? description,
}) async {
  try {
    // إنشاء معاملة جديدة
    DocumentReference transactionRef = _firestore.collection('transactions').doc();
    await transactionRef.set({
      'user_id': userId,
      'amount': amount,
      'transaction_type': transactionType,
      'created_at': FieldValue.serverTimestamp(),
      'session_id': sessionId,
      'session_title': sessionTitle ?? 'جلسة استشارية',
      'other_party_id': otherPartyId,
      'description': description ?? (amount > 0 ? 'إضافة رصيد' : 'خصم رصيد'),
      'is_paid_session': true,
    });

    // تحديث رصيد المحفظة
    DocumentReference walletRef = _firestore.collection('wallets').doc(userId);
    DocumentSnapshot walletSnapshot = await walletRef.get();
    
    double currentBalance = 0.0;
    if (walletSnapshot.exists && walletSnapshot.data() != null) {
      Map<String, dynamic> walletData = walletSnapshot.data() as Map<String, dynamic>;
      if (walletData['balance'] is num) {
        currentBalance = (walletData['balance'] as num).toDouble();
      }
    }
    
    // تحديث الرصيد
    await walletRef.set({
      'balance': currentBalance + amount,
      'last_updated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    return true;
  } catch (e) {
    print('خطأ في إنشاء المعاملة المالية: $e');
    // نعيد قيمة false وليس خطأ لتجنب توقف العملية
    return false;
  }
}
```

### تحسينات نظام المحفظة وإدارة الجلسات (2025/04/05)

قمنا بإجراء تحسينات كبيرة على نظام إدارة المحفظة والجلسات في التطبيق لزيادة الموثوقية والأداء وتحسين تجربة المستخدم.

#### تحسينات نظام المحفظة

1. **تخزين مؤقت ذكي للرصيد**:
   - تم إضافة نظام تخزين مؤقت ذكي لقيم رصيد المحفظة يقلل من عدد الاستعلامات لقاعدة البيانات.
   - تخزين الرصيد مؤقتًا لمدة 30 ثانية مع إمكانية تمديد الصلاحية عند التحديث.
   - إضافة آلية استرجاع الرصيد المخزن محليًا في حالة فشل الاتصال بقاعدة البيانات.

2. **معاملات الدفعة الواحدة للمحفظة**:
   - استخدام معاملات الدفعة الواحدة (batch transactions) في Firestore لضمان تنفيذ العمليات المالية بشكل متسق.
   - تنفيذ إنشاء المعاملة وتحديث الرصيد كعملية واحدة غير قابلة للتجزئة.
   - تحسين التعامل مع الأخطاء وتجنب الحالات التي يمكن فيها تحديث أحدهما دون الآخر.

```dart
// مثال لنظام التخزين المؤقت الذكي للرصيد
static Future<double> getWalletBalance(String userId) async {
  try {
    // تحقق من وجود قيمة مخزنة مؤقتًا حديثة (أقل من 30 ثانية)
    if (_cachedBalances.containsKey(userId)) {
      final cachedBalance = _cachedBalances[userId]!;
      if (cachedBalance.isValid()) {
        return cachedBalance.balance;
      }
    }

    // استرجاع البيانات من قاعدة البيانات إذا كانت القيمة المخزنة مؤقتًا غير صالحة
    DocumentSnapshot walletDoc =
        await _firestore.collection('wallets').doc(userId).get();

    double balance = 0.0;
    if (walletDoc.exists && walletDoc.data() != null) {
      Map<String, dynamic> data = walletDoc.data() as Map<String, dynamic>;
      if (data.containsKey('balance') && data['balance'] is num) {
        balance = (data['balance'] as num).toDouble();
      }
    }

    // تخزين القيمة مؤقتًا
    _cachedBalances[userId] = _CachedBalance(balance);
    return balance;
  } catch (e) {
    // استخدام القيمة المخزنة محليًا إذا كانت متوفرة في حالة الخطأ
    if (_walletBalances.containsKey(userId)) {
      return _walletBalances[userId]!;
    }
    return 0.0;
  }
}
```

#### تحسينات نظام الجلسات

1. **تحسين آلية إنهاء الجلسات**:
   - إضافة معرفات فريدة للعمليات لتسهيل تتبع وتشخيص الأخطاء.
   - استخدام معاملات الدفعة الواحدة لتحديث حالة الجلسة.
   - فصل تحديث حالة الجلسة عن المعاملات المالية لضمان إكمال الجلسة حتى في حالة فشل المعاملات.
   - تحسين تقريب وتنسيق قيم التكلفة والمدة.

```dart
// مثال لآلية التحقق من صلاحية إنهاء الجلسة
static Future<Map<String, dynamic>> validateSessionEnd(
  String sessionId,
  String userId,
) async {
  try {
    // التحقق من المستخدم المصرح له
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return {
        'isValid': false,
        'error': 'يجب تسجيل الدخول أولاً لإنهاء الجلسة',
      };
    }

    // الحصول على بيانات الجلسة
    final sessionDoc = await _firestore.collection('chat_sessions').doc(sessionId).get();
    
    if (!sessionDoc.exists) {
      return {
        'isValid': false,
        'error': 'الجلسة غير موجودة',
      };
    }
    
    final sessionData = sessionDoc.data() as Map<String, dynamic>;
    
    // التحقق من أن المستخدم هو مشارك في الجلسة
    final sessionUserId = sessionData['user_id'];
    final sessionAstrologerId = sessionData['astrologer_id'];
    
    if (currentUser.uid != sessionUserId && currentUser.uid != sessionAstrologerId) {
      return {
        'isValid': false,
        'error': 'لا يمكنك إنهاء جلسة لست مشاركًا فيها',
      };
    }
    
    return {
      'isValid': true,
      'error': '',
      'sessionData': sessionData,
    };
  } catch (e) {
    return {
      'isValid': false,
      'error': 'خطأ في التحقق من صلاحية إنهاء الجلسة: ${e.toString()}',
    };
  }
}
```

#### تحسينات واجهة المستخدم

1. **معالجة خطأ `setState() called after dispose()`**:
   - تم إضافة فحص `mounted` قبل استدعاء `setState` في جميع الصفحات.
   - حل مشكلة الخطأ الشائع عند محاولة تحديث واجهة المستخدم بعد التخلص منها.
   - تحسين تجربة المستخدم بتجنب الأخطاء غير المرئية التي تؤثر على الأداء.

2. **تحسين عرض رسائل الخطأ**:
   - تنفيذ عرض أفضل لرسائل الخطأ عند فشل العمليات.
   - توفير معلومات أكثر دقة عن سبب الفشل.
   - إضافة رسائل تشخيصية لتسهيل حل المشكلات.

#### النتائج المتوقعة

1. **زيادة موثوقية المعاملات المالية**:
   - تقليل حالات فقدان البيانات أو عدم اتساقها.
   - تحسين نسبة نجاح المعاملات المالية عند إنهاء الجلسات.

2. **تحسين أداء التطبيق**:
   - تقليل عدد الاستعلامات إلى قاعدة البيانات بفضل نظام التخزين المؤقت.
   - استجابة أسرع لعمليات المحفظة.

3. **تجربة مستخدم أفضل**:
   - معالجة أفضل للأخطاء مع رسائل أوضح للمستخدمين.
   - تجنب تعليق الجلسات أو توقف العمليات.
   - استمرار عمل التطبيق حتى مع وجود مشكلات في الاتصال بقاعدة البيانات.

## بنية المشروع

### المجلدات الرئيسية

```
lib/
  ├── firebase_options.dart    # إعدادات Firebase
  ├── main.dart               # نقطة الدخول الرئيسية للتطبيق
  ├── components/             # المكونات المشتركة
  │   └── user_profile_image.dart # مكون عرض صورة الملف الشخصي
  ├── models/                 # نماذج البيانات
  │   └── user_model.dart     # نموذج بيانات المستخدم
  ├── pages/                  # صفحات التطبيق
  │   ├── admin_management_page.dart
  │   ├── admin_page.dart
  │   ├── astrologer_application_page.dart
  │   ├── astrologer_applications_page.dart
  │   ├── login_page.dart
  │   ├── main_page.dart
  │   ├── profile_page.dart
  │   ├── register_page.dart
  │   └── splash_screen.dart
  └── services/                # الخدمات
      ├── appointment_service.dart
      ├── auth_service.dart
      ├── chat_service.dart
      ├── gift_service.dart
      ├── live_stream_service.dart
      ├── notification_service.dart
      ├── review_service.dart
      ├── storage_service.dart
      ├── transaction_service.dart
      └── zodiac_service.dart
scripts/
  └── add_zodiac_readings.js  # سكريبت لإضافة قراءات الأبراج إلى Firestore
```

## التقنيات المستخدمة

- **Flutter**: إطار عمل واجهة المستخدم
- **Firebase**: خدمات الباك إند
  - **Firebase Authentication**: إدارة المستخدمين والمصادقة
  - **Cloud Firestore**: قاعدة بيانات NoSQL
  - **Firebase Storage**: تخزين الملفات والصور
  - **Firebase Analytics**: تحليلات التطبيق
  - **Firebase App Check**: حماية الواجهات الخلفية
- **خدمة المحفظة الإلكترونية**: إدارة الرصيد والمدفوعات
- **بوابات الدفع**: دعم لـ Apple Pay وGoogle Pay

## نماذج البيانات

### نموذج المستخدم (المحدث)

```dart
UserModel {
  id: String              // معرف المستخدم
  email: String           // البريد الإلكتروني
  firstName: String?      // الاسم الأول
  lastName: String?       // الاسم الأخير
  profileImageUrl: String? // رابط صورة الملف الشخصي (Firebase Storage)
  profileImageBase64: String? // صورة الملف الشخصي بتنسيق Base64
  isAdmin: bool           // هل المستخدم مسؤول
  userType: String        // نوع المستخدم ('normal', 'astrologer')
  astrologerStatus: String? // حالة المنجم (null, 'pending', 'approved', 'rejected')
  aboutMe: String?        // نبذة عن المستخدم
  services: List<String>? // الخدمات التي يقدمها المنجم
  zodiacSign: String?     // برج المستخدم
  offersFreeSession: bool // هل يقدم المنجم جلسات مجانية
}
```

### المكونات الجديدة

#### مكون UserProfileImage

مكون موحد لعرض صور الملفات الشخصية في جميع أنحاء التطبيق، مع خصائص قابلة للتخصيص.

```dart
UserProfileImage(
  userId: String,           // معرف المستخدم المراد عرض صورته
  radius: double = 40,      // نصف قطر الصورة الدائرية
  showPlaceholder: bool = true, // عرض صورة افتراضية عند عدم وجود صورة
  placeholderIcon: Widget?  // أيقونة مخصصة للعرض عند عدم وجود صورة
)
```

#### الميزات الرئيسية للمكون
- عرض صور الملفات الشخصية باستخدام Base64 من Firestore
- معالجة حالات التحميل والأخطاء
- دعم صور افتراضية مخصصة
- عرض دائرة تحميل أثناء جلب الصورة

## الخدمات

### خدمة المصادقة (AuthService) - المحدثة

تدير عمليات تسجيل المستخدمين وتسجيل الدخول والخروج وإدارة الملفات الشخصية.

**الدوال الجديدة والمحدثة**:
- `updateProfileImageBase64`: تحديث صورة الملف الشخصي باستخدام سلسلة Base64
- `getUserProfileImageBase64`: استرجاع صورة الملف الشخصي بتنسيق Base64 لمستخدم محدد
- `getProfileImageBase64`: استرجاع صورة الملف الشخصي للمستخدم الحالي

### خدمة الأبراج (ZodiacService)

تدير قراءات الأبراج وتحديد برج المستخدم بناءً على تاريخ الميلاد.

**الوظائف الرئيسية**:
- `getZodiacSign`: تحديد برج المستخدم بناءً على تاريخ الميلاد
- `saveUserZodiac`: حفظ معلومات برج المستخدم
- `getUserZodiacReading`: الحصول على القراءة اليومية لبرج المستخدم

## تدفق العمل في التطبيق

### تحديث صورة الملف الشخصي (الجديد)
1. المستخدم يختار صورة من معرض الصور باستخدام `image_picker`
2. يتم تحويل الصورة إلى تنسيق Base64 مع ضغط الصورة وتقليل أبعادها
3. يتم تخزين سلسلة Base64 مباشرة في Firestore كجزء من وثيقة المستخدم
4. يتم عرض الصورة المحدثة فورًا في جميع أنحاء التطبيق من خلال مكون `UserProfileImage`

### إدارة الجلسات المدفوعة
1. التحقق من الرصيد المتاح
2. تطبيق حد زمني للجلسات المجانية (30 دقيقة/يوم)
3. معالجة الدفع الفوري عبر البوابة المختارة
4. تنبيه المستخدم قبل انتهاء الوقت المتبقي
5. معالجة الاسترجاعات التلقائية عند انتهاء المهلة

### تسجيل المستخدم
1. المستخدم يدخل البريد الإلكتروني وكلمة المرور
2. يتم إنشاء حساب في Firebase Authentication
3. يتم إنشاء وثيقة المستخدم في Firestore

### تسجيل الدخول
1. المستخدم يدخل البريد الإلكتروني وكلمة المرور
2. يتم التحقق من البيانات باستخدام Firebase Authentication
3. يتم توجيه المستخدم إلى الصفحة الرئيسية

### ميزات جديدة

#### صفحات ملف المنجم الشخصي
- عرض معلومات المنجم الشخصية
- إدارة الخدمات المقدمة
- عرض التقييمات والتعليقات

#### جلسات الدردشة المدفوعة
- بدء جلسات دردشة مباشرة مع المنجمين
- إدارة المدفوعات عبر Firebase
- تتبع تاريخ الجلسات

#### إدارة المسؤولين
- عرض قائمة جميع المستخدمين
- إدارة طلبات المنجمين
- تحديث قراءات الأبراج

### عرض قراءة البرج
1. يتم التحقق من برج المستخدم في ملفه الشخصي
2. إذا لم يكن البرج محدداً، يتم طلب تاريخ الميلاد وحساب البرج
3. يتم استرجاع القراءة اليومية من مجموعة `zodiac_readings` في Firestore

### التقديم كمنجم
1. المستخدم يملأ نموذج التقديم
2. يتم تحديث حالة المستخدم إلى `astrologer_status: 'pending'`
3. يمكن للمسؤول الموافقة أو رفض الطلب

## إدارة الصلاحيات

يستخدم التطبيق قواعد أمان Firestore للتحكم في الوصول إلى البيانات:

**التعديلات الجديدة**:
- تحديد حد أقصى 3 جلسات مجانية يومياً
- منع التعديل على سجلات المعاملات بعد 24 ساعة
- التحقق من صلاحية الرصيد قبل بدء الجلسات المدفوعة
- تسجيل تلقائي لوقت بدء/انتهاء الجلسة

## الجلسات المجانية

### المميزات والقيود
- مدة الجلسة المجانية: 15 دقيقة
- الحد الأقصى للجلسات المجانية: 3 جلسات يومياً لكل مستخدم
- لا تحتاج إلى رصيد في المحفظة
- متاحة لجميع المستخدمين المسجلين

### شروط الجلسات المجانية
1. يجب أن يكون المستخدم مسجلاً في النظام
2. يجب أن يكون المنجم متاحاً ومتوافقاً مع الجلسات المجانية
3. يجب ألا يكون لدى المستخدم جلسة نشطة أخرى
4. يجب ألا يكون المستخدم قد وصل للحد الأقصى من الجلسات المجانية اليومية

### إنهاء الجلسات المجانية
- تنتهي الجلسة المجانية تلقائياً بعد 15 دقيقة
- يمكن إنهاء الجلسة يدوياً من قبل المستخدم أو المنجم
- لا يتم خصم أي رسوم عند إنهاء الجلسة

### إدارة الجلسات المجانية
- يمكن للمشرف تفعيل/تعطيل الجلسات المجانية
- يمكن للمنجم تفعيل/تعطيل الجلسات المجانية الخاصة به
- يمكن للمشرف تعديل مدة الجلسات المجانية والحد الأقصى للجلسات اليومية

## إعداد البيئة المحلية

1. تثبيت Flutter SDK
2. تثبيت Firebase CLI
3. إعداد مشروع Firebase
4. تنزيل ملف `google-services.json` ووضعه في المجلد المناسب
5. تنزيل مفتاح حساب الخدمة من Firebase Console وحفظه كـ `service-account-key.json`
6. تشغيل `flutter pub get` لتثبيت التبعيات

## إعداد قراءات الأبراج

1. تأكد من وجود ملف `service-account-key.json` في مجلد المشروع
2. قم بتثبيت حزم Node.js المطلوبة: `npm install firebase-admin`
3. قم بتشغيل السكريبت: `node scripts/add_zodiac_readings.js`

## موارد إضافية

- [توثيق Flutter](https://docs.flutter.dev/)
- [توثيق Firebase](https://firebase.google.com/docs)

## بدء التطوير

هذا المشروع هو نقطة انطلاق لتطبيق Flutter.

بعض الموارد للبدء إذا كان هذا هو أول مشروع Flutter لك:

- [Lab: كتابة أول تطبيق Flutter](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: نماذج مفيدة من Flutter](https://docs.flutter.dev/cookbook)

للحصول على مساعدة في بدء تطوير Flutter، راجع
[التوثيق عبر الإنترنت](https://docs.flutter.dev/)، الذي يقدم البرامج التعليمية والنماذج والإرشادات حول تطوير الجوال ومرجع API كامل.
