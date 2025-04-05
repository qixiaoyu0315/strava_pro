# STRAVA—PRO

## 1.准备工作

### 1.1.获取Strava api

https://developers.strava.com/

### 1.2.修改strava问题

 strava_client: ^2.1.3

### 1.3.配置Java环境

在不同开发环境中，Java路径可能不同。项目提供了自动配置脚本：

```bash
# 运行此脚本自动配置Java路径
./scripts/setup_java_path.sh
```

该脚本会根据当前操作系统自动设置合适的Java路径。如果遇到Java路径问题，请先运行此脚本。

## 2.应用更新与发布

### 2.1 设置GitHub Actions自动构建

本项目使用GitHub Actions自动构建和发布Android应用。当推送带有标签(tag)的提交时，将触发自动构建并创建GitHub Release。

要设置自动构建，需要添加以下GitHub Secrets:

1. `KEYSTORE_BASE64`: 密钥库文件的Base64编码
2. `KEYSTORE_PASSWORD`: 密钥库密码
3. `KEY_PASSWORD`: 密钥密码
4. `KEY_ALIAS`: 密钥别名

可以使用以下命令将密钥库编码为Base64格式:

```bash
./scripts/encode_keystore.sh android/app/keystore/strava_pro.keystore
```

### 2.2 创建新发布版本

使用以下脚本创建新版本并推送到GitHub:

```bash
./scripts/create_release.sh
```

### 2.3 应用内自动更新

应用内置了自动更新检查功能，定期检查GitHub上的最新发布版本。如有更新，将提示用户下载并安装。

> **注意**：当前版本暂时禁用了自动安装APK功能，因为`install_plugin`插件存在命名空间兼容性问题。
> 下载APK后，系统将使用默认方式打开APK文件，需要用户手动完成安装。
> 
> 如需恢复自动安装功能，请参阅[应用更新功能指南](docs/APP_UPDATE_GUIDE.md)了解如何修复`install_plugin`插件问题。

### 2.4 Android构建问题修复

如果在构建过程中遇到以下错误：

```
Namespace not specified. Specify a namespace in the module's build file.
```

请运行修复脚本：

```bash
./scripts/fix_install_plugin.sh
```

详细信息请参阅[命名空间修复指南](android/NAMESPACE_FIX_README.md)。

## 已知待修复问题

1. 首次安装应用，设置页面认证不成功，需要退出app，重新进入进行认证即可
2. 导航页面横向纵向切换时缓慢
3. 进入导航缓慢
4. 定位刷新可以更快些
5. 海拔图中的提示框会超出边界

## 功能更新

0. 优先处理

- ~~增加信息的本地存储，减少不必要的请求~~

1. 设置页面

- ~~认证页面修改，跳转到新的页面去做认证~~
- ~~设置页面在认证后显示头像、用户名、取消认证~~
- ~~取消认证后，按钮显示为认证~~
- ~~增加设置点击直接下载解析gpx文件，而不用每次手动下载~~
- ~~海拔高度图显示方式~~

2. 路线页面

- 增加刷新数据按钮

- 海拔高度图

  - 优化显示数据超出问题
  - 优化Y轴显示问题

  - 增加海拔高度图区间随地图显示，而不只是显示全程，特殊操作后显示全程高度等
  - 增加手动拖动等操作

- 地图的定位到当前位置按钮

3.瓦片地图的缓存，减少数据加载
4.路线页面可切换其他授权用户

## 问题结局

### 1.Flutter 卡在 "Running Gradle task 'assembleDebug'... "

```shell
#直到发现了这篇文章： Flutter App stuck at "Running Gradle task 'assembleDebug'... "
#处理方法如下:
1.  Open your flutter Project directory.
2.  Change directory to android directory in your flutter project directory `cd android`
3.  clean gradle `./gradlew clean`
4.  Build gradle `./gradlew build` or you can combine both commands with just `./gradlew clean build` (Thanks @daniel for the tip)
5.  Now run your flutter project. If you use vscode, press F5. First time gradle running assembleDebug will take time.
    执行 gradlew clean 后，会有下载 jar 的日志输出（下载了多少/jar 多大）直观明了。
```

### 2.stravaclient包问题处理

- /Users/qixiaoyu/.pub-cache/hosted/pub.dev/strava_client-2.1.2/lib/src/domain/model/model_summary_athlete.dart

​        需要增加判断

```dart
country: json["country"] == null ? "" : json["country"],
```

- /Users/qixiaoyu/.pub-cache/hosted/pub.dev/strava_client-2.1.2/lib/src/domain/model/model_route.dart segments 相关注释

```dart
class MapUrls {
  final String? url;
  final String? retinaUrl;
  final String? lightUrl;
  final String? darkUrl;

  MapUrls({this.url, this.retinaUrl, this.lightUrl, this.darkUrl});

  MapUrls.fromJson(Map<String, dynamic> json)
      : url = json['url'],
        retinaUrl = json['retina_url'],
        lightUrl = json['light_url'],
        darkUrl = json['dark_url'];

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'retina_url': retinaUrl,
      'light_url': lightUrl,
      'dark_url': darkUrl,
    };
  }
}

class Route {
  // 其他属性...
  MapUrls? mapUrls; // 添加 mapUrls 属性

  Route({
    // 其他参数...
    this.mapUrls,
  });

  Route.fromJson(dynamic json) {
    // 其他解析...
    mapUrls = json['map_urls'] != null ? MapUrls.fromJson(json['map_urls']) : null; // 解析 map_urls
  }

  Map<String, dynamic> toJson() {
    var jsonMap = <String, dynamic>{};
    // 其他序列化...
    if (mapUrls != null) {
      jsonMap['map_urls'] = mapUrls!.toJson(); // 序列化 map_urls
    }
    return jsonMap;
  }
} 
```







































