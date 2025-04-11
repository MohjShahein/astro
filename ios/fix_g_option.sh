#!/bin/bash

# تعيين مسار المشروع
PROJECT_DIR="/Users/mohj/Desktop/latest working update/ios"
PODS_DIR="$PROJECT_DIR/Pods"

# التأكد من وجود مجلد Pods
if [ ! -d "$PODS_DIR" ]; then
    echo "مجلد Pods غير موجود في $PROJECT_DIR"
    exit 1
fi

echo "البحث عن الملفات التي تحتوي على خيار -G وإزالته..."

# البحث في ملفات المصدر
find "$PODS_DIR" -type f \( -name "*.c" -o -name "*.cc" -o -name "*.h" -o -name "*.m" \) -exec sed -i '' 's/-G[[:alnum:]_]*//g' {} +

# البحث في ملفات xcconfig
find "$PODS_DIR" -type f -name "*.xcconfig" -exec sed -i '' 's/-G[[:alnum:]_]*//g' {} +

# البحث في ملفات المشروع
find "$PROJECT_DIR" -type f -name "*.pbxproj" -exec sed -i '' 's/-G[[:alnum:]_]*//g' {} +

echo "تم الانتهاء من إزالة خيار -G"
echo "يرجى تشغيل 'flutter run' مرة أخرى" 