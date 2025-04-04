#!/bin/bash

# 该脚本用于将密钥库文件编码为base64，以便上传到GitHub Secrets

# 参数检查
if [ $# -eq 0 ]; then
  echo "用法: $0 <keystore文件路径>"
  exit 1
fi

KEYSTORE_PATH="$1"

if [ ! -f "$KEYSTORE_PATH" ]; then
  echo "错误: 文件 '$KEYSTORE_PATH' 不存在!"
  exit 1
fi

# Base64编码密钥库
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS使用不同的base64参数
  base64 -i "$KEYSTORE_PATH"
else
  # Linux和其他系统
  base64 -w 0 "$KEYSTORE_PATH"
fi

echo ""
echo "请复制上面的base64输出，并将其添加到GitHub repository secrets中，名称为KEYSTORE_BASE64"
echo "同时还需要添加以下secrets:"
echo "- KEYSTORE_PASSWORD: 密钥库密码（123456）"
echo "- KEY_PASSWORD: 密钥密码（123456）"
echo "- KEY_ALIAS: 密钥别名（strava_pro）" 