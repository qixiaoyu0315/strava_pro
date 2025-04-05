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

echo "密钥库文件信息:"
ls -la "$KEYSTORE_PATH"

# 尝试读取密钥库信息以验证其有效性
echo "请输入密钥库密码验证:"
read -s KEYSTORE_PASSWORD
echo ""

if ! keytool -list -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASSWORD" > /dev/null 2>&1; then
  echo "错误: 无法使用提供的密码打开密钥库！"
  exit 1
else
  echo "密钥库验证成功，包含以下条目:"
  keytool -list -keystore "$KEYSTORE_PATH" -storepass "$KEYSTORE_PASSWORD" | grep "Entry"
fi

# 创建临时文件
TEMP_FILE=$(mktemp)
echo "创建临时文件: $TEMP_FILE"

# Base64编码密钥库
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS使用不同的base64参数
  base64 -i "$KEYSTORE_PATH" > "$TEMP_FILE"
else
  # Linux和其他系统
  base64 -w 0 "$KEYSTORE_PATH" > "$TEMP_FILE"
fi

# 验证编码和解码
echo "验证base64编码和解码..."
TEMP_DECODED=$(mktemp)
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS的解码
  base64 -D -i "$TEMP_FILE" > "$TEMP_DECODED"
else
  # Linux的解码
  base64 --decode "$TEMP_FILE" > "$TEMP_DECODED"
fi

# 比较文件是否相同
if cmp -s "$KEYSTORE_PATH" "$TEMP_DECODED"; then
  echo "✅ Base64编码验证成功!"
else
  echo "❌ 警告: Base64编码和解码后文件不一致!"
  exit 1
fi

# 清理临时文件
rm "$TEMP_DECODED"

# 输出Base64编码
echo ""
echo "===== 以下是base64编码后的密钥库文件 ====="
cat "$TEMP_FILE"
echo ""
echo "===== base64编码结束 ====="

# 提供文件大小信息
ORIGINAL_SIZE=$(wc -c < "$KEYSTORE_PATH")
ENCODED_SIZE=$(wc -c < "$TEMP_FILE")
echo ""
echo "原始文件大小: $ORIGINAL_SIZE 字节"
echo "Base64编码后大小: $ENCODED_SIZE 字节"

# 清理临时文件
rm "$TEMP_FILE"

echo ""
echo "请复制上面的base64输出，并将其添加到GitHub repository secrets中，名称为KEYSTORE_BASE64"
echo "确保完整复制所有字符，不要漏掉任何字符!"
echo ""
echo "同时还需要添加以下secrets:"
echo "- KEYSTORE_PASSWORD: 密钥库密码"
echo "- KEY_PASSWORD: 密钥密码"
echo "- KEY_ALIAS: 密钥别名" 