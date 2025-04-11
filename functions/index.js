const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// وظيفة لإنشاء توكن Agora (يجب استبدالها بمنطق التوكن الفعلي)
exports.generateAgoraToken = functions.https.onCall(async (data, context) => {
  // التحقق من أن المستخدم مسجل الدخول
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'يجب تسجيل الدخول لإنشاء توكن'
    );
  }

  const { channelName, uid, role } = data;
  
  // التحقق من وجود المعلومات المطلوبة
  if (!channelName) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'اسم القناة مطلوب'
    );
  }

  // هنا يجب إضافة منطق إنشاء التوكن الفعلي باستخدام مكتبة Agora
  // هذا مثال بسيط فقط
  const token = {
    appId: 'APP_ID_PLACEHOLDER',
    channelName: channelName,
    uid: uid || context.auth.uid,
    role: role || 1, // افتراضي: منشئ البث
    expirationTimeInSeconds: 3600, // ساعة واحدة
    token: 'TOKEN_PLACEHOLDER_' + channelName + '_' + Date.now()
  };

  return { success: true, ...token };
});

// وظيفة للتحقق من صلاحيات المستخدم
exports.checkUserPermissions = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'يجب تسجيل الدخول للتحقق من الصلاحيات'
    );
  }

  const userId = context.auth.uid;
  const userDoc = await db.collection('users').doc(userId).get();
  
  if (!userDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'المستخدم غير موجود'
    );
  }

  const userData = userDoc.data();
  return {
    isAdmin: userData.isAdmin || false,
    isAstrologer: userData.isAstrologer || false,
    roles: userData.roles || []
  };
});

// وظيفة لإضافة مشاهد إلى البث المباشر
exports.addViewerToStream = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'يجب تسجيل الدخول لإضافة مشاهد'
    );
  }

  const userId = context.auth.uid;
  const { streamId } = data;

  if (!streamId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'معرف البث مطلوب'
    );
  }

  try {
    const streamRef = db.collection('live_streams').doc(streamId);
    const streamDoc = await streamRef.get();

    if (!streamDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'البث المباشر غير موجود'
      );
    }

    const streamData = streamDoc.data();
    if (streamData.status !== 'live') {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'البث المباشر غير نشط'
      );
    }

    // تحقق مما إذا كان المستخدم موجودًا بالفعل
    const viewers = streamData.viewers || [];
    if (viewers.includes(userId)) {
      return { success: true, alreadyViewing: true };
    }

    // استخدام batch لضمان التحديث الذري
    const batch = db.batch();
    batch.update(streamRef, {
      viewers: admin.firestore.FieldValue.arrayUnion(userId),
      viewerCount: admin.firestore.FieldValue.increment(1),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });

    await batch.commit();
    return { success: true };
  } catch (error) {
    console.error('خطأ في إضافة مشاهد:', error);
    throw new functions.https.HttpsError(
      'internal',
      'حدث خطأ أثناء إضافة المشاهد',
      error.message
    );
  }
});

// وظيفة لتحديث قواعد أمان Firestore بشكل ديناميكي (مثال فقط)
exports.updateFirestoreRules = functions.https.onCall(async (data, context) => {
  // هذه الوظيفة هي مثال فقط، في الواقع لا يمكن تحديث قواعد الأمان من خلال وظائف Cloud
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'يجب تسجيل الدخول لتحديث القواعد'
    );
  }

  // تحقق من أن المستخدم مسؤول
  const userDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!userDoc.exists || !userDoc.data().isAdmin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'يجب أن تكون مسؤولاً لتحديث القواعد'
    );
  }

  return {
    success: true,
    message: 'قواعد الأمان محدثة (ملاحظة: هذه وظيفة توضيحية فقط)'
  };
}); 