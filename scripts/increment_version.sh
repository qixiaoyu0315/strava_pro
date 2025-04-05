#!/bin/bash

# 该脚本用于自动增加pubspec.yaml中的构建号

PUBSPEC_FILE="pubspec.yaml"

if [ ! -f "$PUBSPEC_FILE" ]; then
  echo "错误: 找不到pubspec.yaml文件"
  exit 1
fi

# 获取当前版本
CURRENT_VERSION=$(grep "version:" "$PUBSPEC_FILE" | sed -E 's/version: (.*)/\1/')
echo "当前版本: $CURRENT_VERSION"

# 分离语义版本和构建号
if [[ $CURRENT_VERSION =~ ([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+) ]]; then
  SEMANTIC_VERSION="${BASH_REMATCH[1]}"
  BUILD_NUMBER="${BASH_REMATCH[2]}"
  
  # 增加构建号
  NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
  NEW_VERSION="${SEMANTIC_VERSION}+${NEW_BUILD_NUMBER}"
  
  echo "更新版本号: $CURRENT_VERSION -> $NEW_VERSION"
  
  # 在Linux和macOS上使用不同的sed命令
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/version: ${CURRENT_VERSION}/version: ${NEW_VERSION}/g" "$PUBSPEC_FILE"
  else
    # Linux
    sed -i "s/version: ${CURRENT_VERSION}/version: ${NEW_VERSION}/g" "$PUBSPEC_FILE"
  fi
  
  echo "版本号已更新: $NEW_VERSION"
else
  echo "错误: 无法解析版本号格式: $CURRENT_VERSION"
  exit 1
fi 