import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'logger.dart';

/// 小组件管理器
/// 提供初始化和更新小组件的方法
class WidgetManager {
  // 小组件相关常量 - 确保与Kotlin代码中的值一致
  static const String appGroupId = 'com.example.strava_pro';
  static const String calendarWidgetKey = 'calendar_widget';
  static const String imagePathKey =
      'calendar_image_path'; // 与CalendarWidgetReceiver.IMAGE_PATH_KEY一致

  /// 初始化小组件服务
  static Future<void> initialize() async {
    try {
      // 设置应用组ID
      await HomeWidget.setAppGroupId(appGroupId);

      // 注册小组件点击回调
      HomeWidget.registerBackgroundCallback(backgroundCallback);

      Logger.d('小组件服务初始化成功', tag: 'WidgetManager');
    } catch (e) {
      Logger.e('小组件服务初始化失败', error: e, tag: 'WidgetManager');
    }
  }

  /// 更新日历小组件
  static Future<bool> updateCalendarWidget({String? imagePath}) async {
    try {
      final String calendarImagePath = imagePath ??
          '/storage/emulated/0/Download/strava_pro/month/2025_01_calendar.png';

      // 检查图片是否存在
      final imageFile = File(calendarImagePath);
      if (!await imageFile.exists()) {
        Logger.e('要显示的图片不存在: $calendarImagePath', tag: 'WidgetManager');
        return false;
      }

      // 保存图片路径到小组件数据 - 确保键与CalendarWidgetReceiver中一致
      await HomeWidget.saveWidgetData(imagePathKey, calendarImagePath);

      // 请求更新小组件
      await HomeWidget.updateWidget(
        androidName: 'CalendarWidgetReceiver',
        iOSName: 'CalendarWidget',
      );

      Logger.d('日历小组件更新成功，图片路径: $calendarImagePath', tag: 'WidgetManager');
      return true;
    } catch (e) {
      Logger.e('更新日历小组件失败', error: e, tag: 'WidgetManager');
      return false;
    }
  }

  /// 小组件点击回调
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    if (uri == null) return;

    Logger.d('收到小组件回调: ${uri.toString()}', tag: 'WidgetManager');

    // 处理不同的小组件点击事件
    switch (uri.host) {
      case 'calendar_widget_clicked':
        // 处理日历小组件点击
        break;
      default:
        break;
    }
  }
}
