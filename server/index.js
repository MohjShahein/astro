const express = require('express');
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');
const dotenv = require('dotenv');
const cors = require('cors');

// تحميل المتغيرات البيئية من ملف .env
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// تكوين CORS بشكل واضح للسماح بطلبات من أي مصدر
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
  credentials: true
}));

// ضبط رؤوس إضافية لمنع مشاكل CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept');
  res.header('Access-Control-Allow-Credentials', true);
  
  // معالجة طلبات OPTIONS مباشرة
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }
  
  next();
});

// استخدام القيم من متغيرات البيئة مع التحقق من صحتها
const APP_ID = process.env.AGORA_APP_ID;
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE;

// التحقق من وجود القيم الضرورية
if (!APP_ID || !APP_CERTIFICATE) {
  console.error('❌ AGORA_APP_ID أو AGORA_APP_CERTIFICATE غير معرفة في ملف .env');
  process.exit(1);
}

console.log('✅ معرف التطبيق:', APP_ID);
console.log('✅ شهادة التطبيق:', APP_CERTIFICATE.substring(0, 5) + '...');

// توثيق طلبات الخادم وإضافة سجلات أكثر تفصيلاً
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.url} من ${req.ip}`);
  if (Object.keys(req.query).length > 0) {
    console.log(`معلمات الاستعلام:`, req.query);
  }
  
  // قياس الوقت المستغرق للاستجابة
  const start = Date.now();
  res.on('finish', () => {
    const duration = Date.now() - start;
    console.log(`[${timestamp}] استجابة: ${res.statusCode} (${duration}ms)`);
  });
  
  next();
});

// نقطة نهاية ping للتحقق من أن الخادم يعمل
app.get('/ping', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    appId: APP_ID,
    hasCertificate: !!APP_CERTIFICATE
  });
});

// إنشاء توكن لـ Agora
app.get('/token', (req, res) => {
  try {
    const channelName = req.query.channelName || req.query.channel;
    const uid = parseInt(req.query.uid || '0');
    const role = req.query.role ? parseInt(req.query.role) : RtcRole.PUBLISHER;
    
    console.log('✅ طلب توكن جديد - القناة:', channelName, 'معرف المستخدم:', uid, 'الدور:', role);
    
    if (!channelName) {
      console.error('❌ طلب غير صالح: اسم القناة مفقود');
      return res.status(400).json({ error: 'يجب تحديد معلمة channelName أو channel' });
    }
    
    // إنشاء التوكن مع وقت صلاحية (بالثواني)
    const expirationTimeInSeconds = 3600; // 1 ساعة
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;
    
    console.log('بدء إنشاء التوكن...');
    console.log('معرف التطبيق:', APP_ID);
    console.log('اسم القناة:', channelName);
    console.log('معرف المستخدم:', uid);
    console.log('الدور:', role);
    console.log('وقت الصلاحية:', currentTimestamp);
    console.log('وقت انتهاء الصلاحية:', privilegeExpiredTs);
    
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      uid,
      role,
      privilegeExpiredTs
    );
    
    console.log('✅ تم إنشاء التوكن بنجاح:', token.substring(0, 15) + '...');
    
    res.json({
      token: token,
      appId: APP_ID,
      channelName: channelName,
      uid: uid,
      role: role,
      expires: privilegeExpiredTs,
      expiresIn: expirationTimeInSeconds
    });
    
  } catch (error) {
    console.error('❌ خطأ في إنشاء التوكن:', error);
    res.status(500).json({ 
      error: 'فشل في إنشاء التوكن',
      details: error.message
    });
  }
});

// نقطة نهاية جذرية للاختبار
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head>
        <title>خادم توكن Agora</title>
        <style>
          body { font-family: Arial, sans-serif; text-align: center; margin: 50px; }
          h1 { color: #333; }
          .btn { 
            padding: 10px 20px; 
            background: #4CAF50; 
            color: white; 
            border: none; 
            border-radius: 4px;
            margin: 10px;
            text-decoration: none;
            display: inline-block;
          }
          pre { 
            background: #f4f4f4; 
            padding: 15px; 
            border-radius: 5px; 
            text-align: left; 
            max-width: 600px; 
            margin: auto;
          }
        </style>
      </head>
      <body>
        <h1>خادم توكن Agora</h1>
        <p>الخادم يعمل على المنفذ ${PORT}</p>
        <div>
          <a href="/ping" class="btn">اختبار ping</a>
          <a href="/token?channelName=test&uid=0&role=1" class="btn">اختبار التوكن</a>
        </div>
        <h2>كيفية الاستخدام:</h2>
        <pre>
GET /token?channelName=CHANNEL_NAME&uid=USER_ID&role=ROLE

المعلمات:
- channelName: اسم القناة (إلزامي)
- uid: معرف المستخدم (اختياري، الافتراضي: 0)
- role: الدور (اختياري، الافتراضي: 1 للمذيع)
        </pre>
      </body>
    </html>
  `);
});

// تشغيل الخادم
app.listen(PORT, 'localhost', () => {
  console.log(`✅ خادم توكن Agora يعمل على المنفذ ${PORT}`);
  console.log(`🔍 للتحقق من حالة الخادم: http://localhost:${PORT}/ping`);
  console.log(`🔑 للحصول على توكن: http://localhost:${PORT}/token?channelName=اسم_القناة&uid=معرف_المستخدم&role=الدور`);
}); 