#!/bin/bash

# 该脚本用于验证密钥库文件和密码

# 参数检查
if [ $# -eq 0 ]; then
  echo "用法: $0 <keystore文件路径> [密码]"
  exit 1
fi

KEYSTORE_PATH="$1"
PASSWORD="$2"

if [ ! -f "$KEYSTORE_PATH" ]; then
  echo "错误: 文件 '$KEYSTORE_PATH' 不存在!"
  exit 1
fi

# 如果没有提供密码，则请求输入
if [ -z "$PASSWORD" ]; then
  echo "请输入密钥库密码:"
  read -s PASSWORD
  echo ""
fi

# 显示密钥库信息
echo "密钥库文件: $KEYSTORE_PATH"
echo "文件大小: $(wc -c < "$KEYSTORE_PATH") 字节"
echo "文件权限: $(ls -la "$KEYSTORE_PATH" | awk '{print $1}')"

# 尝试使用密码打开密钥库
echo "尝试使用提供的密码打开密钥库..."
if keytool -list -keystore "$KEYSTORE_PATH" -storepass "$PASSWORD" > /tmp/keystore_info 2>&1; then
  echo "✅ 密钥库验证成功!"
  echo ""
  echo "密钥库包含以下条目:"
  cat /tmp/keystore_info
  
  # 尝试使用同样的密码获取私钥
  echo ""
  echo "尝试获取私钥信息..."
  ALIAS=$(grep "Entry" /tmp/keystore_info | head -1 | awk -F, '{print $1}')
  if [ -n "$ALIAS" ]; then
    echo "检测到密钥别名: $ALIAS"
    if keytool -list -v -keystore "$KEYSTORE_PATH" -storepass "$PASSWORD" -alias "$ALIAS" > /dev/null 2>&1; then
      echo "✅ 成功使用相同密码访问私钥!"
    else
      echo "❌ 无法使用相同密码访问私钥，可能密钥密码不同"
      echo "请输入密钥密码:"
      read -s KEY_PASSWORD
      if keytool -list -v -keystore "$KEYSTORE_PATH" -storepass "$PASSWORD" -keypass "$KEY_PASSWORD" -alias "$ALIAS" > /dev/null 2>&1; then
        echo "✅ 使用不同的密钥密码成功访问私钥!"
        echo "请确保在GitHub Secrets中设置了正确的KEY_PASSWORD!"
      else
        echo "❌ 仍然无法访问私钥"
      fi
    fi
  else
    echo "❌ 无法检测到密钥别名"
  fi
else
  echo "❌ 无法使用提供的密码打开密钥库!"
  cat /tmp/keystore_info
fi

# 清理临时文件
rm -f /tmp/keystore_info 