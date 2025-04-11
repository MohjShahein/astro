# تطبيق الأبراج

## إعداد قراءات الأبراج في Firestore

لتمكين قراءات الأبراج اليومية في التطبيق، يجب اتباع الخطوات التالية:

### 1. تحديث قواعد الأمان في Firestore

قم بنسخ محتوى ملف `firestore.rules` إلى قواعد الأمان في Firebase Console:

1. انتقل إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك `astrology-d317e`
3. انتقل إلى Firestore Database
4. انقر على تبويب "Rules"
5. انسخ محتوى ملف `firestore.rules` واستبدل القواعد الحالية
6. انقر على "Publish"

### تحديثات مهمة في قواعد الأمان (أبريل 2025)

تم تحديث القواعد مؤخرًا لحل مشكلة في إنشاء المعاملات المالية وتحديث محافظ المستخدمين. يجب أن تحتوي القواعد على ما يلي:

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

هذه التعديلات ضرورية لضمان أن:
1. أي مستخدم مسجل يمكنه إنشاء معاملات مالية (ضروري لإتمام عمليات الدفع)
2. أي مستخدم مسجل يمكنه تحديث المحافظ (ضروري لإتمام عمليات نقل الأموال)
3. فقط المشرفين يمكنهم تعديل أو حذف المعاملات المالية بعد إنشائها

ملاحظة: تأكد من استخدام الدالة `isAdmin` مع تمرير `request.auth.uid` كمعلمة لها.

### 2. إنشاء مجموعة قراءات الأبراج

يمكنك إضافة قراءات الأبراج بإحدى الطريقتين:

#### الطريقة الأولى: استخدام Firebase Console

1. انتقل إلى Firestore Database في Firebase Console
2. أنشئ مجموعة جديدة باسم `zodiac_readings`
3. لكل برج، أنشئ وثيقة باسم البرج (aries, taurus, gemini, إلخ)
4. أضف حقل `daily_reading` من نوع string يحتوي على القراءة اليومية

#### الطريقة الثانية: استخدام سكريبت Node.js

1. قم بتنزيل مفتاح حساب الخدمة من Firebase Console:
   - انتقل إلى إعدادات المشروع
   - انتقل إلى "Service accounts"
   - انقر على "Generate new private key"
   - احفظ الملف واستبدل به محتوى `service-account-key.json`

2. قم بتثبيت حزم Node.js المطلوبة:
   ```bash
   npm install firebase-admin
   ```

3. قم بتشغيل السكريبت:
   ```bash
   node scripts/add_zodiac_readings.js
   ```

### 3. هيكل البيانات

يستخدم التطبيق الهيكل التالي لتخزين واسترجاع قراءات الأبراج:

```
zodiac_readings/
  aries/
    daily_reading: "نص القراءة اليومية لبرج الحمل"
  taurus/
    daily_reading: "نص القراءة اليومية لبرج الثور"
  ...
```

### ملاحظات هامة

- تأكد من أن المستخدم مسجل الدخول قبل محاولة استرداد قراءات الأبراج
- تأكد من تحديث قواعد الأمان في Firestore للسماح بقراءة مجموعة `zodiac_readings`
- إذا كنت تستخدم Firebase App Check، تأكد من تكوينه بشكل صحيح للسماح بالوصول إلى Firestore