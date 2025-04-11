#!/bin/bash

# تأكد من تثبيت التبعيات أولاً
flutter pub get
cd ios
pod install

echo "بدء عملية إصلاح ملفات BoringSSL في المشروع..."

# تعديل ملفات البناء في Xcode
find . -name "*.xcconfig" -type f -exec grep -l -- "-G" {} \; | while read -r file; do
    echo "إصلاح ملف: $file"
    sed -i '' 's/-G[[:space:]]*[[:graph:]]*//g; s/-G$//g; s/-G,//g; s/,-G//g' "$file"
done

# تعديل ملفات المصدر C/C++
find . -name "*.c" -o -name "*.cc" -o -name "*.h" -o -name "*.m" | while read -r file; do
    if grep -q -- "-G" "$file"; then
        echo "إصلاح ملف المصدر: $file"
        sed -i '' 's/-G[[:space:]]*[[:graph:]]*//g; s/-G$//g; s/-G,//g; s/,-G//g' "$file"
    fi
done

# تحديد ملفات البناء الخاصة بـ BoringSSL وإصلاحها مباشرة
echo "تحديد ملفات BoringSSL الخاصة..."
BORING_SSL_FILES=$(find . -path "*/BoringSSL-GRPC/src/crypto/fipsmodule/*" -type f)
for file in $BORING_SSL_FILES; do
    echo "إصلاح ملف BoringSSL المحدد: $file"
    sed -i '' 's/-G[[:space:]]*[[:graph:]]*//g; s/-G$//g; s/-G,//g; s/,-G//g' "$file"
done

# تعديل الإعدادات المخزنة داخل ملفات .pbxproj
PBXPROJ_FILES=$(find . -name "*.pbxproj" -type f)
for file in $PBXPROJ_FILES; do
    echo "إصلاح ملف بناء Xcode: $file"
    sed -i '' 's/"OTHER_CFLAGS[^"]*-G[^"]*"/"OTHER_CFLAGS"/g' "$file"
    sed -i '' 's/"OTHER_CPLUSPLUSFLAGS[^"]*-G[^"]*"/"OTHER_CPLUSPLUSFLAGS"/g' "$file"
    sed -i '' 's/"OTHER_LDFLAGS[^"]*-G[^"]*"/"OTHER_LDFLAGS"/g' "$file"
done

echo "تم الانتهاء من إصلاح ملفات المشروع. العودة للمجلد الرئيسي..."
cd ..

echo "يمكنك الآن تنفيذ أمر: flutter build ios --no-codesign" 