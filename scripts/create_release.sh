#!/bin/bash

# 该脚本用于创建新版本并推送到GitHub，触发自动构建和发布流程

# 确保工作目录干净
if [[ ! -z $(git status --porcelain) ]]; then
  echo "错误: 工作目录不干净，请先提交或暂存所有更改"
  exit 1
fi

# 获取当前版本
CURRENT_VERSION=$(grep "version:" pubspec.yaml | sed -E 's/version: (.*)/\1/')
echo "当前版本: $CURRENT_VERSION"

# 询问新版本号
read -p "请输入新版本号 (格式: x.y.z，当前: $CURRENT_VERSION): " NEW_VERSION

# 验证版本号格式
if ! [[ $NEW_VERSION =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "错误: 无效的版本号格式. 请使用格式 x.y.z"
  exit 1
fi

# 询问构建号
read -p "请输入构建号 (数字，例如: 1): " BUILD_NUMBER

# 验证构建号格式
if ! [[ $BUILD_NUMBER =~ ^[0-9]+$ ]]; then
  echo "错误: 无效的构建号格式. 请使用数字"
  exit 1
fi

# 完整版本号 (包含构建号)
FULL_VERSION="${NEW_VERSION}+${BUILD_NUMBER}"

# 更新pubspec.yaml中的版本号
sed -i.bak "s/version: ${CURRENT_VERSION}/version: ${FULL_VERSION}/" pubspec.yaml
rm pubspec.yaml.bak

echo "已更新pubspec.yaml中的版本号为 ${FULL_VERSION}"

# 提交版本变更
git add pubspec.yaml
git commit -m "chore: 版本升级到 ${FULL_VERSION}"

# 创建标签（只使用语义版本部分，不包括构建号）
TAG_NAME="v${NEW_VERSION}"
git tag -a "$TAG_NAME" -m "Release ${FULL_VERSION}"

echo "已创建标签: $TAG_NAME （对应版本: ${FULL_VERSION}）"
echo "注意: 标签名仅包含语义版本部分(${TAG_NAME})，但完整版本(${FULL_VERSION})已更新到pubspec.yaml"

# 询问是否推送
read -p "是否推送变更和标签到GitHub? (y/n): " SHOULD_PUSH

if [[ $SHOULD_PUSH == "y" || $SHOULD_PUSH == "Y" ]]; then
  echo "推送变更..."
  git push
  
  echo "推送标签..."
  git push origin "$TAG_NAME"
  
  echo "完成! GitHub Actions将自动构建并发布此版本。"
  echo "可以在以下地址查看进度: https://github.com/qixiaoyu0315/strava_pro/actions"
else
  echo "变更未推送。要手动推送，请运行:"
  echo "  git push"
  echo "  git push origin $TAG_NAME"
fi 