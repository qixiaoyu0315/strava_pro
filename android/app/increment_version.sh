#!/bin/bash

# 找到pubspec.yaml中的版本号行
VERSION_LINE=$(grep -n "version:" ../../pubspec.yaml | cut -d ":" -f 1)

# 提取当前版本号和构建号
CURRENT_VERSION=$(grep "version:" ../../pubspec.yaml | sed -E 's/version: (.*)\+(.*)/\1/')
CURRENT_BUILD=$(grep "version:" ../../pubspec.yaml | sed -E 's/version: (.*)\+(.*)/\2/')

# 递增构建号
NEW_BUILD=$((CURRENT_BUILD + 1))

# 更新pubspec.yaml文件
sed -i "" "${VERSION_LINE}s/version: ${CURRENT_VERSION}+${CURRENT_BUILD}/version: ${CURRENT_VERSION}+${NEW_BUILD}/" ../../pubspec.yaml

echo "版本号已更新: ${CURRENT_VERSION}+${NEW_BUILD}" 