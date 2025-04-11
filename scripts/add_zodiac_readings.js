const admin = require('firebase-admin');
const serviceAccount = require('../service-account-key.json');

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Daily readings for each zodiac sign
const zodiacReadings = {
  aries: {
    daily_reading: 'ستواجه اليوم فرصًا جديدة للنمو. كن مستعدًا لاتخاذ المبادرة والمضي قدمًا في مشاريعك.'
  },
  taurus: {
    daily_reading: 'اليوم مناسب للاستقرار والتأمل. ركز على بناء الأسس المتينة لمستقبلك.'
  },
  gemini: {
    daily_reading: 'تواصلك سيكون في أفضل حالاته اليوم. استغل هذه الطاقة للتعبير عن أفكارك وبناء علاقات جديدة.'
  },
  cancer: {
    daily_reading: 'العواطف قوية اليوم. خذ وقتًا للاعتناء بنفسك وبمن تحب.'
  },
  leo: {
    daily_reading: 'إبداعك في ذروته. استغل هذه الطاقة لإظهار مواهبك والتألق في مجالك.'
  },
  virgo: {
    daily_reading: 'التفاصيل مهمة اليوم. ركز على تنظيم حياتك وتحسين روتينك اليومي.'
  },
  libra: {
    daily_reading: 'ابحث عن التوازن في علاقاتك وقراراتك. الدبلوماسية ستكون مفتاح نجاحك اليوم.'
  },
  scorpio: {
    daily_reading: 'حدسك قوي اليوم. ثق بمشاعرك الداخلية واستكشف الأعماق.'
  },
  sagittarius: {
    daily_reading: 'المغامرة تناديك. استكشف آفاقًا جديدة وتوسع في معرفتك.'
  },
  capricorn: {
    daily_reading: 'التركيز على أهدافك المهنية سيؤتي ثماره. اعمل بجد واستمر في التقدم.'
  },
  aquarius: {
    daily_reading: 'أفكارك المبتكرة ستلهم من حولك. شارك رؤيتك للمستقبل مع الآخرين.'
  },
  pisces: {
    daily_reading: 'حساسيتك وإبداعك في أوجهما. استمع إلى حدسك واترك خيالك يقودك.'
  }
};

// Add zodiac readings to Firestore
async function addZodiacReadings() {
  try {
    for (const [sign, data] of Object.entries(zodiacReadings)) {
      await db.collection('zodiac_readings').doc(sign).set(data);
      console.log(`Added reading for ${sign}`);
    }
    console.log('All zodiac readings have been added successfully!');
  } catch (error) {
    console.error('Error adding zodiac readings:', error);
  } finally {
    process.exit();
  }
}

addZodiacReadings();