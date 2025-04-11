#!/bin/bash

# تعيين مسار المشروع
PROJECT_DIR="$(pwd)"
PODS_DIR="${PROJECT_DIR}/ios/Pods"

echo "Fixing BoringSSL-GRPC -G flag issue..."

# البحث عن جميع الملفات التي تحتوي على الخيار -G وإزالته منها
find "${PODS_DIR}" -name "*.c" -o -name "*.h" -o -name "*.cc" -o -name "*.m" | while read -r file; do
    if grep -q -- "-G" "$file"; then
        echo "Fixing file: $file"
        # استبدال الخيار -G بـ 
        sed -i '' 's/-G / /g' "$file"
        sed -i '' 's/-G$//g' "$file"
        sed -i '' 's/-G,/ /g' "$file"
        sed -i '' 's/,-G/ /g' "$file"
    fi
done

# تعديل ملفات xcconfig لإزالة الخيار -G
find "${PODS_DIR}/Target Support Files" -name "*.xcconfig" | while read -r file; do
    if grep -q -- "-G" "$file"; then
        echo "Fixing xcconfig file: $file"
        sed -i '' 's/-G / /g' "$file"
        sed -i '' 's/-G$//g' "$file"
        sed -i '' 's/-G,/ /g' "$file"
        sed -i '' 's/,-G/ /g' "$file"
    fi
done

echo "Fixing complete. Now run 'flutter build ios'" 