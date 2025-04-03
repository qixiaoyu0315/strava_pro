import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/month_grid.dart';
import '../widgets/week_grid.dart';
import '../utils/widget_to_image.dart';
import '../utils/logger.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'widget_manager.dart';

/// 日历导出工具
class CalendarExporter {
  /// 导出指定月份的日历为图片
  static Future<String?> exportMonth({
    required BuildContext context,
    required DateTime month,
    DateTime? selectedDate,
    Map<String, bool>? svgCache,
    String? customPath,
  }) async {
    // 首先检查并请求权限
    if (Platform.isAndroid) {
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        Fluttertoast.showToast(
          msg: '没有存储权限，无法导出日历',
          toastLength: Toast.LENGTH_LONG,
        );
        return null;
      }
    }

    try {
      // 创建一个GlobalKey用于截图
      final GlobalKey repaintKey = GlobalKey();

      // 格式化月份名称用于文件名
      final DateFormat formatter = DateFormat('yyyy_MM');
      final String monthStr = formatter.format(month);

      // 设置输出路径
      final String outputDir =
          customPath ?? '/storage/emulated/0/Download/strava_pro/month';
      final String fileName = '${monthStr}_calendar.png';
      final String outputPath = '$outputDir/$fileName';

      // 创建一个临时Overlay用于渲染MonthGrid
      OverlayEntry? entry;

      // 设置一个Completer来等待渲染完成
      final completer = Completer<String?>();

      // 创建Overlay入口
      entry = OverlayEntry(
        builder: (context) {
          return Positioned(
            left: -99999, // 放在屏幕外不可见的位置
            top: -99999,
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 月份标题
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        DateFormat('yyyy年MM月').format(month),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 星期标题行
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text('一',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('二',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('三',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('四',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('五',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('六',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          Text('日', style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    // 月份网格
                    RepaintBoundary(
                      key: repaintKey,
                      child: Container(
                        width: 350, // 固定宽度以确保布局一致
                        height: 350, // 固定高度
                        child: MonthGrid(
                          month: month,
                          selectedDate: selectedDate ?? DateTime.now(),
                          svgCache: svgCache ?? {},
                          onDateSelected: (_) {}, // 空函数，因为这只是截图
                        ),
                      ),
                    ),
                    // 提示信息 - 导出日期
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      alignment: Alignment.centerRight,
                      child: Text(
                        '导出时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // 将Overlay添加到屏幕
      Overlay.of(context).insert(entry);

      // 延迟一下，确保渲染完成
      await Future.delayed(const Duration(milliseconds: 300));

      // 捕获图像并保存
      final String? savedPath = await WidgetToImage.captureAndSave(
        key: repaintKey,
        outputPath: outputPath,
      );

      // 移除Overlay
      entry.remove();

      if (savedPath != null) {
        // 显示导出成功对话框
        if (context.mounted) {
          _showExportSuccessDialog(context, savedPath, month);
        }

        Fluttertoast.showToast(
          msg: '日历已导出到: $savedPath',
          toastLength: Toast.LENGTH_LONG,
        );
        Logger.d('日历导出成功: $savedPath', tag: 'CalendarExporter');

        // 导出成功后，更新小组件显示
        await WidgetManager.updateCalendarWidget(imagePath: savedPath);

        return savedPath;
      } else {
        Fluttertoast.showToast(
          msg: '导出失败，请检查权限设置',
          toastLength: Toast.LENGTH_LONG,
        );
        return null;
      }
    } catch (e) {
      Logger.e('导出月历失败', error: e, tag: 'CalendarExporter');
      Fluttertoast.showToast(
        msg: '导出失败: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      return null;
    }
  }

  /// 导出当前周的日历为图片
  static Future<String?> exportWeek({
    required BuildContext context,
    required DateTime weekStart, // 周的起始日期（周一）
    DateTime? selectedDate,
    Map<String, bool>? svgCache,
    String? customPath,
  }) async {
    // 首先检查并请求权限
    if (Platform.isAndroid) {
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        Fluttertoast.showToast(
          msg: '没有存储权限，无法导出周历',
          toastLength: Toast.LENGTH_LONG,
        );
        return null;
      }
    }

    try {
      // 创建一个GlobalKey用于截图
      final GlobalKey repaintKey = GlobalKey();

      // 格式化日期用于文件名
      final weekEndDate =
          DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
      final DateFormat formatter = DateFormat('yyyyMMdd');
      final String weekStr =
          '${formatter.format(weekStart)}_${formatter.format(weekEndDate)}';

      // 设置输出路径
      final String outputDir =
          customPath ?? '/storage/emulated/0/Download/strava_pro/week';
      final String fileName = 'week_${weekStr}.png';
      final String outputPath = '$outputDir/$fileName';

      // 确保输出目录存在
      final outputDirectory = Directory(outputDir);
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
      }

      // 创建一个临时Overlay用于渲染WeekGrid
      OverlayEntry? entry;

      // 设置一个Completer来等待渲染完成
      final completer = Completer<String?>();

      // 创建Overlay入口
      entry = OverlayEntry(
        builder: (context) {
          return Positioned(
            left: -99999, // 放在屏幕外不可见的位置
            top: -99999,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 400,
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 周标题
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '${DateFormat('MM月dd日').format(weekStart)} - ${DateFormat('MM月dd日').format(weekEndDate)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 星期标题行
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text('周一',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('周二',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('周三',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('周四',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('周五',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color)),
                          Text('周六',
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).colorScheme.primary)),
                          Text('周日',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red)),
                        ],
                      ),
                    ),
                    // 周视图
                    RepaintBoundary(
                      key: repaintKey,
                      child: Container(
                        width: 380,
                        height: 80,
                        child: WeekGrid(
                          weekStart: weekStart,
                          selectedDate: selectedDate ?? DateTime.now(),
                          svgCache: svgCache ?? {},
                          daySize: 45.0,
                        ),
                      ),
                    ),
                    // 提示信息 - 导出日期
                    Container(
                      padding: const EdgeInsets.only(top: 16),
                      alignment: Alignment.centerRight,
                      child: Text(
                        '导出时间: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      // 将Overlay添加到屏幕
      Overlay.of(context).insert(entry);

      // 延迟一下，确保渲染完成
      await Future.delayed(const Duration(milliseconds: 300));

      // 捕获图像并保存
      final String? savedPath = await WidgetToImage.captureAndSave(
        key: repaintKey,
        outputPath: outputPath,
      );

      // 移除Overlay
      entry.remove();

      if (savedPath != null) {
        // 显示导出成功对话框
        if (context.mounted) {
          _showWeekExportSuccessDialog(context, savedPath, weekStart);
        }

        Fluttertoast.showToast(
          msg: '周历已导出到: $savedPath',
          toastLength: Toast.LENGTH_LONG,
        );
        Logger.d('周历导出成功: $savedPath', tag: 'CalendarExporter');

        // 导出成功后，更新小组件显示
        await WidgetManager.updateWeekWidget(imagePath: savedPath);

        return savedPath;
      } else {
        Fluttertoast.showToast(
          msg: '导出失败，请检查权限设置',
          toastLength: Toast.LENGTH_LONG,
        );
        return null;
      }
    } catch (e) {
      Logger.e('导出周历失败', error: e, tag: 'CalendarExporter');
      Fluttertoast.showToast(
        msg: '导出失败: $e',
        toastLength: Toast.LENGTH_LONG,
      );
      return null;
    }
  }

  // 显示导出成功对话框
  static void _showExportSuccessDialog(
      BuildContext context, String path, DateTime month) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导出成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${DateFormat('yyyy年MM月').format(month)} 的月历已成功导出'),
            SizedBox(height: 8),
            Text(
              '保存路径：$path',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openExportedImage(path);
            },
            child: Text('查看图片'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateWidget(path);
            },
            child: Text('更新小组件'),
          ),
        ],
      ),
    );
  }

  // 显示周历导出成功对话框
  static void _showWeekExportSuccessDialog(
      BuildContext context, String path, DateTime weekStart) {
    final weekEndDate =
        DateTime(weekStart.year, weekStart.month, weekStart.day + 6);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('导出成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                '${DateFormat('MM月dd日').format(weekStart)} - ${DateFormat('MM月dd日').format(weekEndDate)} 的周历已成功导出'),
            SizedBox(height: 8),
            Text(
              '保存路径：$path',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openExportedImage(path);
            },
            child: Text('查看图片'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _updateWeekWidget(path);
            },
            child: Text('更新小组件'),
          ),
        ],
      ),
    );
  }

  // 更新小组件
  static Future<void> _updateWidget(String imagePath) async {
    try {
      final success =
          await WidgetManager.updateCalendarWidget(imagePath: imagePath);
      if (success) {
        Fluttertoast.showToast(
          msg: '小组件已更新',
          toastLength: Toast.LENGTH_SHORT,
        );
      } else {
        Fluttertoast.showToast(
          msg: '小组件更新失败',
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '更新小组件失败: $e',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  // 更新周小组件
  static Future<void> _updateWeekWidget(String path) async {
    final success = await WidgetManager.updateWeekWidget(imagePath: path);
    if (success) {
      Fluttertoast.showToast(
        msg: '周历小组件已更新',
        toastLength: Toast.LENGTH_SHORT,
      );
    } else {
      Fluttertoast.showToast(
        msg: '周历小组件更新失败',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  // 打开导出的图片文件
  static Future<void> _openExportedImage(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        Fluttertoast.showToast(
          msg: '无法打开文件: ${result.message}',
          toastLength: Toast.LENGTH_SHORT,
        );
        Logger.e('打开文件失败: ${result.message}', tag: 'CalendarExporter');
      }
    } catch (e) {
      Logger.e('打开文件异常', error: e, tag: 'CalendarExporter');
      Fluttertoast.showToast(
        msg: '打开文件失败: $e',
        toastLength: Toast.LENGTH_SHORT,
      );
    }
  }

  // 请求存储权限
  static Future<bool> _requestStoragePermission() async {
    try {
      // 对于Android 10（API级别29）及以上，需要请求MANAGE_EXTERNAL_STORAGE权限
      // 对于较低版本，需要READ_EXTERNAL_STORAGE和WRITE_EXTERNAL_STORAGE权限

      if (Platform.isAndroid) {
        // 确保导出目录存在
        await _ensureDirectoryExists(
            '/storage/emulated/0/Download/strava_pro/month');

        // 检查当前权限状态
        PermissionStatus status = await Permission.storage.status;
        Logger.d('当前存储权限状态: $status', tag: 'CalendarExporter');

        if (status.isGranted) {
          return true;
        }

        // 请求权限
        status = await Permission.storage.request();
        Logger.d('请求后存储权限状态: $status', tag: 'CalendarExporter');

        if (status.isGranted) {
          return true;
        } else if (status.isPermanentlyDenied) {
          // 用户永久拒绝了权限，需要引导他们去设置中开启
          Fluttertoast.showToast(
            msg: '存储权限被拒绝，请在设置中开启',
            toastLength: Toast.LENGTH_LONG,
          );
        }

        return status.isGranted;
      }

      // 在iOS上，不需要特殊的存储权限
      return true;
    } catch (e) {
      Logger.e('请求存储权限失败', error: e, tag: 'CalendarExporter');
      return false;
    }
  }

  // 确保目录存在
  static Future<void> _ensureDirectoryExists(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
        Logger.d('创建目录成功: $path', tag: 'CalendarExporter');
      }
    } catch (e) {
      Logger.e('创建目录失败', error: e, tag: 'CalendarExporter');
    }
  }
}
