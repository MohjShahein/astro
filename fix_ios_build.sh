#!/bin/bash

echo "===== بدء عملية إصلاح مشكلة بناء تطبيق iOS ====="

# تثبيت التبعيات
echo "جاري تثبيت pods..."
cd ios
pod install --repo-update

echo "جاري البحث عن وإصلاح الملفات التي تحتوي على خيار -G..."

# تحديد موقع ملفات xcconfig
find Pods -name "*.xcconfig" -type f -exec sed -i '' 's/-G[[:space:]]*[[:graph:]]*//g; s/-G$//g' {} \;

# تحديد موقع ملفات المصدر
find Pods -name "*.c" -o -name "*.h" -o -name "*.m" -o -name "*.cc" -type f -exec sed -i '' 's/-G[[:space:]]*[[:graph:]]*//g; s/-G$//g' {} \;

# إزالة ملفات build القديمة التي قد تتداخل
echo "جاري تنظيف مخرجات البناء القديمة..."
cd ..
flutter clean

echo "===== اكتملت عملية الإصلاح ====="
echo "يمكنك الآن تنفيذ أمر 'flutter build ios --no-codesign' لبناء التطبيق" 