#!/bin/bash

# 该脚本用于根据运行环境自动设置正确的Java路径

GRADLE_PROPS_FILE="android/gradle.properties"

# 检测操作系统
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS系统
  if [ -d "/opt/homebrew/opt/openjdk@17" ]; then
    echo "在macOS上设置Java路径为 /opt/homebrew/opt/openjdk@17"
    # 先删除已有的Java Home设置
    sed -i.bak '/org.gradle.java.home/d' $GRADLE_PROPS_FILE
    # 添加macOS的Java路径
    echo "org.gradle.java.home=/opt/homebrew/opt/openjdk@17" >> $GRADLE_PROPS_FILE
    echo "✅ Java路径已成功设置为macOS Homebrew路径"
  else
    echo "⚠️ 未找到预期的Java路径，请手动设置Java路径"
  fi
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
  # Windows系统
  if [ -d "C:\\Program Files\\Java\\jdk-17" ]; then
    echo "在Windows上设置Java路径"
    sed -i.bak '/org.gradle.java.home/d' $GRADLE_PROPS_FILE
    echo "org.gradle.java.home=C:\\Program Files\\Java\\jdk-17" >> $GRADLE_PROPS_FILE
    echo "✅ Java路径已成功设置为Windows路径"
  else
    echo "⚠️ 未找到预期的Java路径，请手动设置Java路径"
  fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux系统或CI环境
  echo "在Linux/CI环境上移除固定Java路径设置"
  sed -i '/org.gradle.java.home/d' $GRADLE_PROPS_FILE
  echo "✅ 已移除固定Java路径，将使用系统Java"
else
  echo "⚠️ 未知操作系统: $OSTYPE"
fi

echo "当前gradle.properties内容:"
cat $GRADLE_PROPS_FILE 