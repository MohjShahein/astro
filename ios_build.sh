#!/bin/bash

echo "🧹 تنظيف المشروع..."
flutter clean

echo "🔄 تنظيف مجلد Pods..."
rm -rf ios/Pods
rm -rf ios/Podfile.lock
rm -rf ios/.symlinks
rm -rf ios/Flutter/Flutter.framework
rm -rf ios/Flutter/Flutter.podspec

echo "📦 تحديث حزم Flutter..."
flutter pub get

echo "🛠️ إصلاح أي مشاكل مع CocoaPods..."
cd ios
pod cache clean --all
pod deintegrate
pod setup

echo "🔧 تثبيت حزم iOS..."
pod install --repo-update

echo "🔨 بناء المشروع بدون توقيع..."
cd ..
flutter build ios --no-codesign

echo "✅ اكتمل البناء! الآن عليك فتح المشروع في Xcode وإعداد التوقيع يدوياً:"
echo "open ios/Runner.xcworkspace"

echo "📱 للتشغيل على جهازك، اتبع هذه الخطوات:"
echo "1. افتح Xcode: open ios/Runner.xcworkspace"
echo "2. حدد Runner في الشريط الجانبي"
echo "3. انتقل إلى علامة تبويب Signing & Capabilities"
echo "4. تأكد من تحديد فريق التطوير الخاص بك لـ Runner فقط (ليس للـ Pods)"
echo "5. تأكد من تفعيل خيار 'Automatically manage signing'"
echo "6. اختر جهازك من قائمة الأجهزة"
echo "7. اضغط على زر التشغيل (أو Command+R)"

# فتح المشروع في Xcode تلقائياً
open ios/Runner.xcworkspace 