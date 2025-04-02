import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:path_provider/path_provider.dart';
import 'logger.dart';

class PolylineToPNG {
  /// 将 Polyline 字符串转换为 PNG 并保存到指定路径
  ///
  /// [polylineStr] - Polyline 字符串
  /// [outputPath] - 输出 PNG 文件的路径
  /// [width] - PNG 图像的宽度（默认 800）
  /// [height] - PNG 图像的高度（默认 600）
  /// [strokeColor] - 线条颜色（默认 Colors.green）
  /// [strokeWidth] - 线条宽度（默认 10）
  ///
  /// 返回生成的 PNG 文件路径，如果发生错误则返回 null
  static Future<String?> generateAndSavePNG(
    String polylineStr,
    String outputPath, {
    double width = 800,
    double height = 600,
    Color strokeColor = Colors.green,
    double strokeWidth = 10,
  }) async {
    try {
      // 解码 polyline
      List<List<double>> points = _decodePolyline(polylineStr);
      if (points.isEmpty) {
        Logger.w('错误：无效的 Polyline 字符串', tag: 'PNG');
        return null;
      }

      // 计算边界
      double minX = points.map((p) => p[0]).reduce(min);
      double maxX = points.map((p) => p[0]).reduce(max);
      double minY = points.map((p) => p[1]).reduce(min);
      double maxY = points.map((p) => p[1]).reduce(max);

      // 计算中心点
      double centerX = (minX + maxX) / 2;
      double centerY = (minY + maxY) / 2;

      // 计算缩放比例
      double scale = min(width / (maxX - minX), height / (maxY - minY)) * 0.8; // 留出一些边距

      // 计算偏移量，使路线居中
      double offsetX = width / 2 - centerX * scale;
      double offsetY = height / 2 - centerY * scale;

      // 创建图像记录器
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // 设置透明背景
      final paint = Paint()
        ..color = strokeColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      // 绘制路径
      final path = Path();
      bool isFirst = true;
      for (var point in points) {
        double x = point[0] * scale + offsetX;
        double y = height - (point[1] * scale + offsetY); // 反转 Y 轴方向
        
        if (isFirst) {
          path.moveTo(x, y);
          isFirst = false;
        } else {
          path.lineTo(x, y);
        }
      }
      
      canvas.drawPath(path, paint);

      // 完成绘制并转换为图像
      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      
      // 转换为PNG字节数据
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('无法将图像转换为字节数据');
      }
      
      final pngBytes = byteData.buffer.asUint8List();

      // 确保目录存在
      final directory = Directory(outputPath).parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 保存文件
      final file = File(outputPath);
      await file.writeAsBytes(pngBytes);
      Logger.i('PNG 文件已保存到: $outputPath', tag: 'PNG');

      return outputPath;
    } catch (e) {
      Logger.e('生成 PNG 时发生错误', error: e, tag: 'PNG');
      return null;
    }
  }

  /// 使用 `flutter_polyline_points` 解码 polyline
  static List<List<double>> _decodePolyline(String polylineStr) {
    try {
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(polylineStr);
      return result
          .map((p) => _wgs84ToWebMercator(p.longitude, p.latitude))
          .toList();
    } catch (e) {
      Logger.e('Polyline 解码错误', error: e, tag: 'PNG');
      return [];
    }
  }

  /// WGS84 转换为 Web Mercator
  static List<double> _wgs84ToWebMercator(double lon, double lat) {
    double x = lon * 20037508.34 / 180;
    double y = log(tan((90 + lat) * pi / 360)) / (pi / 180);
    y = y * 20037508.34 / 180;
    return [x, y];
  }
} 