#!/bin/bash

# 该脚本用于修复install_plugin插件的命名空间、编译SDK版本和AndroidManifest问题

# 获取插件路径
PLUGIN_DIR="$HOME/.pub-cache/hosted/pub.dev/install_plugin-2.1.0/android"
PLUGIN_PATH="$PLUGIN_DIR/build.gradle"
MANIFEST_PATH="$PLUGIN_DIR/src/main/AndroidManifest.xml"

echo "正在查找install_plugin插件..."

if [ ! -f "$PLUGIN_PATH" ]; then
    echo "错误: 未找到install_plugin插件。"
    echo "请确认路径是否正确: $PLUGIN_PATH"
    exit 1
fi

echo "找到插件: $PLUGIN_PATH"
echo "开始修复..."

# 备份原文件
cp "$PLUGIN_PATH" "${PLUGIN_PATH}.bak"
echo "已创建备份: ${PLUGIN_PATH}.bak"

# 修改build.gradle文件
cat > "$PLUGIN_PATH" << EOF
apply plugin: 'com.android.library'

def safeExtGet(prop, fallback) {
    rootProject.ext.has(prop) ? rootProject.ext.get(prop) : fallback
}

android {
    namespace "com.zaihui.installplugin"
    
    compileSdkVersion safeExtGet('compileSdkVersion', 33)
    
    defaultConfig {
        minSdkVersion safeExtGet('minSdkVersion', 16)
        targetSdkVersion safeExtGet('targetSdkVersion', 33)
        versionCode 1
        versionName "1.0"
    }
    lintOptions {
        abortOnError false
    }
}

dependencies {
    implementation 'androidx.appcompat:appcompat:1.6.1'
}
EOF

echo "build.gradle文件已修复"

# 修复AndroidManifest.xml文件
if [ -f "$MANIFEST_PATH" ]; then
    # 备份原文件
    cp "$MANIFEST_PATH" "${MANIFEST_PATH}.bak"
    echo "已创建AndroidManifest备份: ${MANIFEST_PATH}.bak"
    
    # 去除package属性
    sed -i.tmp 's/package="[^"]*"//g' "$MANIFEST_PATH"
    rm "${MANIFEST_PATH}.tmp"
    
    echo "AndroidManifest.xml文件已修复"
else
    echo "警告: 未找到AndroidManifest.xml文件: $MANIFEST_PATH"
fi

echo "修复完成！"
echo "现在你可以重新运行构建命令了。" 