# install_plugin 命名空间修复指南

## 问题描述

在构建时遇到以下错误：

```
FAILURE: Build failed with an exception.

* What went wrong:
A problem occurred configuring project ':install_plugin'.
> Could not create an instance of type com.android.build.api.variant.impl.LibraryVariantBuilderImpl.
   > Namespace not specified. Specify a namespace in the module's build file. See https://d.android.com/r/tools/upgrade-assistant/set-namespace for information about setting the namespace.
```

这是因为 `install_plugin` 插件缺少命名空间设置。从Android Gradle Plugin 8.0开始，所有模块必须指定命名空间。

## 解决方案

### 方法1: 使用修复脚本（推荐）

1. 运行提供的修复脚本：

   ```bash
   ./scripts/fix_install_plugin.sh
   ```

   这将自动修复插件的源代码。

### 方法2: 手动修复

1. 找到 `install_plugin` 插件的源代码位置：

   ```
   ~/.pub-cache/hosted/pub.dev/install_plugin-2.1.0/android/build.gradle
   ```

2. 编辑该文件，在 `android {}` 块中添加命名空间定义：

   ```gradle
   android {
       // 其他配置...
       namespace "com.zaihui.installplugin"
   }
   ```

### 方法3: 临时解决方案

项目中已应用临时修复，禁用了 `install_plugin` 依赖项，使构建可以继续进行。
但是，这意味着应用内更新功能（自动安装APK）将不可用，直到问题得到永久修复。

## 注意事项

- 修复后，请重新运行构建命令。
- 如果你更新了Flutter依赖项，可能需要重新应用此修复。 