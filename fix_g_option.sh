#!/bin/bash

cd ios

echo "بحث عن ملفات xcconfig مع خيار -G..."
find Pods -name "*.xcconfig" -type f -exec grep -l -- "-G" {} \; | while read file; do
    echo "إصلاح $file"
    sed -i '' 's/-G[[:space:]]*[[:graph:]]*//g; s/-G$//g; s/-G,//g; s/,-G//g' "$file"
done

echo "فحص ملفات البناء الرئيسية..."
CONFIG_FILES=(
  "./Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
  "./Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig" 
  "./Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"
  "./Pods/Target Support Files/BoringSSL-GRPC/BoringSSL-GRPC.debug.xcconfig"
  "./Pods/Target Support Files/BoringSSL-GRPC/BoringSSL-GRPC.release.xcconfig"
)

for file in "${CONFIG_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "تحديث ملف هام: $file"
    sed -i '' 's/-G[[:space:]]*[[:graph:]]*//g; s/-G$//g; s/-G,//g; s/,-G//g' "$file"
  fi
done

echo "إصلاح ملفات PBXProject..."
find . -name "*.pbxproj" -type f -exec sed -i '' 's/"OTHER_CFLAGS[^"]*-G[^"]*"/"OTHER_CFLAGS"/g' {} \;
find . -name "*.pbxproj" -type f -exec sed -i '' 's/"OTHER_CPLUSPLUSFLAGS[^"]*-G[^"]*"/"OTHER_CPLUSPLUSFLAGS"/g' {} \;

echo "إصلاح ملف GDTCORConsoleLogger.m..."
GDTCOR_FILE="./Pods/GoogleDataTransport/GoogleDataTransport/GDTCORLibrary/GDTCORConsoleLogger.m"
if [ -f "$GDTCOR_FILE" ]; then
  sed -i '' 's/initWithFormat:@"I.*code];/initWithFormat:@"I-%ld", (long)code];/g' "$GDTCOR_FILE"
fi

echo "إصلاح ملف GULUserDefaults.m..."
GUL_FILE="./Pods/GoogleUtilities/GoogleUtilities/UserDefaults/GULUserDefaults.m"
if [ -f "$GUL_FILE" ]; then
  sed -i '' 's/GULLogWarning.*kGULLogUserDefaultsService/GULLogWarning(gul_us, @"GULLogUserDefaultsService"/g' "$GUL_FILE"
fi

echo "إصلاح مشكلة -G في ملفات المصدر الخاصة بـ BoringSSL..."
find ./Pods/BoringSSL-GRPC -name "*.c" -o -name "*.h" -type f -exec grep -l -- "-G" {} \; | while read file; do
    echo "إصلاح $file"
    sed -i '' 's/-G[[:space:]]*[[:graph:]]*//g; s/-G$//g; s/-G,//g; s/,-G//g' "$file"
done

cd ..
echo "اكتمل الإصلاح. يمكنك الآن بناء تطبيق iOS." 