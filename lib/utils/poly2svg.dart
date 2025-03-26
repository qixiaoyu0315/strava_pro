import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class PolylineToSVGScreen extends StatefulWidget {
  @override
  _PolylineToSVGScreenState createState() => _PolylineToSVGScreenState();
}

class _PolylineToSVGScreenState extends State<PolylineToSVGScreen> {
  final TextEditingController _controller = TextEditingController();
  String _svgData = "";

  /// 将 Polyline 字符串转换为 SVG 并保存到指定路径
  ///
  /// [polylineStr] - Polyline 字符串
  /// [outputPath] - 输出 SVG 文件的路径
  /// [width] - SVG 图像的宽度（默认 800）
  /// [height] - SVG 图像的高度（默认 600）
  /// [strokeColor] - 线条颜色（默认 "green"）
  /// [strokeWidth] - 线条宽度（默认 5）
  ///
  /// 返回生成的 SVG 内容字符串，如果发生错误则返回 null
  Future<String?> _generateAndSaveSVG(
    String polylineStr,
    String outputPath, {
    double width = 800,
    double height = 600,
    String strokeColor = "green",
    double strokeWidth = 5,
  }) async {
    try {
      // 解码 polyline
      List<List<double>> points = _decodePolyline(polylineStr);
      if (points.isEmpty) {
        print('错误：无效的 Polyline 字符串');
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
      double scale = min(width / (maxX - minX), height / (maxY - minY));

      // 计算偏移量，使路线居中
      double offsetX = width / 2 - centerX * scale;
      double offsetY = height / 2 - centerY * scale;

      // 生成路径数据
      List<String> pathData = points.map((p) {
        double x = p[0] * scale + offsetX;
        double y = height - (p[1] * scale + offsetY); // 反转 Y 轴方向
        return "${x.toStringAsFixed(2)},${y.toStringAsFixed(2)}";
      }).toList();

      // 生成 SVG 内容
      String svgContent = '''
        <svg viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
          <polyline points="${pathData.join(' ')}" fill="none" stroke="$strokeColor" stroke-width="$strokeWidth"/>
        </svg>
      ''';

      // 确保目录存在
      final directory = Directory(outputPath).parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 保存文件（覆盖已存在的文件）
      final file = File(outputPath);
      await file.writeAsString(svgContent);
      print('SVG 文件已保存到: $outputPath');

      return svgContent;
    } catch (e) {
      print('生成 SVG 时发生错误: $e');
      return null;
    }
  }

  /// 使用 `flutter_polyline_points` 解码 polyline
  List<List<double>> _decodePolyline(String polylineStr) {
    try {
      PolylinePoints polylinePoints = PolylinePoints();
      List<PointLatLng> result = polylinePoints.decodePolyline(polylineStr);
      return result
          .map((p) => _wgs84ToWebMercator(p.longitude, p.latitude))
          .toList();
    } catch (e) {
      print('Polyline 解码错误: $e');
      return [];
    }
  }

  /// WGS84 转换为 Web Mercator
  List<double> _wgs84ToWebMercator(double lon, double lat) {
    double x = lon * 20037508.34 / 180;
    double y = log(tan((90 + lat) * pi / 360)) / (pi / 180);
    y = y * 20037508.34 / 180;
    return [x, y];
  }

  void _generateSVG() async {
    String polylineStr = _controller.text.trim();
    if (polylineStr.isEmpty) {
      setState(() {
        _svgData = "";
      });
      return;
    }

    String? svgContent = await _generateAndSaveSVG(polylineStr, "output.svg");
    if (svgContent == null) {
      setState(() {
        _svgData = "<svg><text>错误：无效的Polyline字符串</text></svg>";
      });
      return;
    }

    setState(() {
      _svgData = svgContent;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Polyline to SVG")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter Polyline String",
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _generateSVG,
              child: Text("Convert to SVG"),
            ),
            SizedBox(height: 20),
            Expanded(
              child: _svgData.isNotEmpty
                  ? Center(
                      child: SizedBox(
                        width: 400,
                        height: 400,
                        child: SvgPicture.string(_svgData, fit: BoxFit.contain),
                      ),
                    )
                  : Center(child: Text("SVG will be shown here")),
            ),
          ],
        ),
      ),
    );
  }
}

class PolylineToSVG {
  /// 将 Polyline 字符串转换为 SVG 并保存到指定路径
  ///
  /// [polylineStr] - Polyline 字符串
  /// [outputPath] - 输出 SVG 文件的路径
  /// [width] - SVG 图像的宽度（默认 800）
  /// [height] - SVG 图像的高度（默认 600）
  /// [strokeColor] - 线条颜色（默认 "green"）
  /// [strokeWidth] - 线条宽度（默认 5）
  ///
  /// 返回生成的 SVG 内容字符串，如果发生错误则返回 null
  static Future<String?> generateAndSaveSVG(
    String polylineStr,
    String outputPath, {
    double width = 800,
    double height = 600,
    String strokeColor = "green",
    double strokeWidth = 10,
  }) async {
    try {
      // 解码 polyline
      List<List<double>> points = _decodePolyline(polylineStr);
      if (points.isEmpty) {
        print('错误：无效的 Polyline 字符串');
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
      double scale = min(width / (maxX - minX), height / (maxY - minY));

      // 计算偏移量，使路线居中
      double offsetX = width / 2 - centerX * scale;
      double offsetY = height / 2 - centerY * scale;

      // 生成路径数据
      List<String> pathData = points.map((p) {
        double x = p[0] * scale + offsetX;
        double y = height - (p[1] * scale + offsetY); // 反转 Y 轴方向
        return "${x.toStringAsFixed(2)},${y.toStringAsFixed(2)}";
      }).toList();

      // 生成 SVG 内容
      String svgContent = '''
        <svg viewBox="0 0 $width $height" xmlns="http://www.w3.org/2000/svg">
          <polyline points="${pathData.join(' ')}" fill="none" stroke="$strokeColor" stroke-width="$strokeWidth"/>
        </svg>
      ''';

      // 确保目录存在
      final directory = Directory(outputPath).parent;
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // 保存文件（覆盖已存在的文件）
      final file = File(outputPath);
      await file.writeAsString(svgContent);
      print('SVG 文件已保存到: $outputPath');

      return svgContent;
    } catch (e) {
      print('生成 SVG 时发生错误: $e');
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
      print('Polyline 解码错误: $e');
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
