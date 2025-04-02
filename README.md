# STRAVA—PRO

## 1.准备工作

### 1.1.获取Strava api

https://developers.strava.com/

### 1.2.修改strava问题

 strava_client: ^2.1.3

## 2.







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







































