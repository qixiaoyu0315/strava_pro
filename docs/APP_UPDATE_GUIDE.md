# 应用更新功能指南

本文档描述了Strava Pro应用中的更新功能实现以及如何解决可能遇到的问题。

## 功能概述

应用更新功能通过以下步骤实现：

1. 检查GitHub发布页面获取最新版本信息
2. 比较本地版本与最新版本
3. 如果有更新，下载并安装新版本APK

## 当前状态

目前，APK下载功能正常工作，但由于Android构建问题，安装APK的功能已被暂时禁用。
我们使用系统默认方式打开APK文件作为替代方案。

## 恢复完整功能

要启用自动安装APK功能，需要修复`install_plugin`插件的命名空间问题：

### 方法1：使用修复脚本

1. 运行提供的修复脚本：
   ```bash
   ./scripts/fix_install_plugin.sh
   ```

2. 修改`pubspec.yaml`，取消注释`install_plugin`依赖：
   ```yaml
   install_plugin: ^2.1.0 # 安装APK
   ```

3. 修改`lib/service/app_update_service.dart`，取消注释相关代码：
   ```dart
   import 'package:install_plugin/install_plugin.dart';
   
   // 在downloadAndInstallUpdate方法中：
   final result = await InstallPlugin.installApk(savePath);
   Logger.d('APK安装结果: $result', tag: 'AppUpdate');
   ```

4. 运行`flutter pub get`更新依赖

### 方法2：更新插件版本

等待`install_plugin`插件更新版本以支持最新的Android Gradle插件要求。

## 插件问题详情

从Android Gradle Plugin 8.0开始，所有模块必须指定命名空间。`install_plugin`插件目前没有指定命名空间，导致构建错误：

```
Namespace not specified. Specify a namespace in the module's build file.
```

我们的解决方案是：
1. 在插件的`build.gradle`文件中添加命名空间定义
2. 从AndroidManifest.xml中移除package属性

## 注意事项

- 每次Flutter依赖更新后，可能需要重新运行修复脚本
- 或者考虑寻找替代`install_plugin`的其他插件
- 如果您只需要打开APK文件，`url_launcher`插件足够使用 