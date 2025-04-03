import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:strava_pro/utils/logger.dart';

/// Widget截图工具类
class WidgetToImage {
  /// 捕获Widget并保存为图片
  static Future<String?> captureAndSave({
    required GlobalKey key,
    required String outputPath,
  }) async {
    try {
      // 确保目录存在
      final directory =
          Directory(outputPath.substring(0, outputPath.lastIndexOf('/')));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 获取RenderObject
      final RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Logger.e('无法获取RenderRepaintBoundary', tag: 'WidgetToImage');
        return null;
      }

      // 渲染为图片
      final double pixelRatio = 3.0; // 提高清晰度
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      // 转换为字节
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        Logger.e('无法将图片转换为ByteData', tag: 'WidgetToImage');
        return null;
      }

      // 写入文件
      final File file = File(outputPath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      Logger.d('Widget截图已保存到: $outputPath', tag: 'WidgetToImage');
      return outputPath;
    } catch (e) {
      Logger.e('捕获Widget并保存失败', error: e, tag: 'WidgetToImage');
      return null;
    }
  }

  /// 将Widget转换为图片
  static Future<ByteData?> capture({
    required GlobalKey key,
    double pixelRatio = 3.0,
  }) async {
    try {
      RenderRepaintBoundary? boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Logger.e('无法找到RenderRepaintBoundary', tag: 'WidgetToImage');
        return null;
      }

      // 等待一帧，确保渲染完成
      await Future.delayed(const Duration(milliseconds: 20));

      ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      return byteData;
    } catch (e) {
      Logger.e('截取Widget为图片失败', error: e, tag: 'WidgetToImage');
      return null;
    }
  }
}
