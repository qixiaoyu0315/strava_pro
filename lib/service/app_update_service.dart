import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
// import 'package:install_plugin/install_plugin.dart'; // 暂时注释掉，解决编译问题
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../utils/logger.dart';

class AppUpdateService {
  static const String _owner = 'qixiaoyu0315';
  static const String _repo = 'strava_pro';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  
  // 检查是否有更新
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // 获取当前应用版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      
      Logger.d('当前应用版本: $currentVersion+$currentBuildNumber', tag: 'AppUpdate');
      
      // 请求GitHub API获取最新发布版本
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String? ?? '';
        
        // 移除版本号前的'v'前缀(如果有)
        final cleanLatestVersion = latestVersion.startsWith('v') 
            ? latestVersion.substring(1) 
            : latestVersion;
            
        Logger.d('GitHub最新版本: $cleanLatestVersion', tag: 'AppUpdate');
        
        // 解析版本号
        List<String> versionParts = cleanLatestVersion.split('+');
        if (versionParts.length != 2) {
          Logger.e('版本格式无效: $cleanLatestVersion', tag: 'AppUpdate');
          return null;
        }
        
        final latestSemanticVersion = versionParts[0];
        final latestBuildNumber = int.tryParse(versionParts[1]) ?? 0;
        
        // 比较版本号
        bool hasUpdate = false;
        
        // 首先比较语义版本
        List<String> currentParts = currentVersion.split('.');
        List<String> latestParts = latestSemanticVersion.split('.');
        
        for (int i = 0; i < Math.min(currentParts.length, latestParts.length); i++) {
          int currentPart = int.tryParse(currentParts[i]) ?? 0;
          int latestPart = int.tryParse(latestParts[i]) ?? 0;
          
          if (latestPart > currentPart) {
            hasUpdate = true;
            break;
          } else if (latestPart < currentPart) {
            return null; // 本地版本更高
          }
        }
        
        // 如果语义版本相同，比较构建号
        if (!hasUpdate && latestBuildNumber > currentBuildNumber) {
          hasUpdate = true;
        }
        
        if (hasUpdate) {
          // 返回更新信息
          return {
            'version': cleanLatestVersion,
            'notes': data['body'] as String? ?? '无更新说明',
            'url': _getApkDownloadUrl(data),
            'publishedAt': data['published_at'] as String? ?? '',
          };
        }
      } else {
        Logger.e('GitHub API请求失败: ${response.statusCode}', tag: 'AppUpdate');
      }
    } catch (e) {
      Logger.e('检查更新时出错', error: e, tag: 'AppUpdate');
    }
    return null;
  }
  
  // 从发布资源中获取APK下载URL
  String _getApkDownloadUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List<dynamic>? ?? [];
    
    // 首先尝试找到以.apk结尾的资源
    for (var asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        return asset['browser_download_url'] as String? ?? '';
      }
    }
    
    // 如果没有找到APK，返回发布页面URL
    return releaseData['html_url'] as String? ?? '';
  }
  
  // 下载并安装更新
  Future<bool> downloadAndInstallUpdate(String url, {
    Function(double)? onProgress,
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    if (!url.endsWith('.apk')) {
      // 如果URL不是APK，打开浏览器
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        if (onError != null) onError('无法打开浏览器');
        return false;
      }
    }
    
    try {
      // 获取临时目录用于保存APK
      final directory = await getTemporaryDirectory();
      final savePath = '${directory.path}/strava_pro_update.apk';
      
      // 使用Dio下载文件
      final dio = Dio();
      await dio.download(
        url, 
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );
      
      // 安装APK - 暂时禁用
      if (Platform.isAndroid) {
        // 由于install_plugin问题，暂时禁用APK安装
        // final result = await InstallPlugin.installApk(savePath);
        // Logger.d('APK安装结果: $result', tag: 'AppUpdate');
        
        // 替代方案：使用系统默认方式打开APK文件
        final apkUri = Uri.file(savePath);
        if (await canLaunchUrl(apkUri)) {
          await launchUrl(apkUri);
          if (onSuccess != null) onSuccess();
          return true;
        } else {
          if (onError != null) onError('无法打开APK文件');
          return false;
        }
      } else {
        if (onError != null) onError('仅支持Android系统');
        return false;
      }
    } catch (e) {
      Logger.e('下载或安装更新时出错', error: e, tag: 'AppUpdate');
      if (onError != null) onError(e.toString());
      return false;
    }
  }
  
  // 显示更新对话框
  void showUpdateDialog(BuildContext context, Map<String, dynamic> updateInfo) {
    final version = updateInfo['version'] as String;
    final notes = updateInfo['notes'] as String;
    final url = updateInfo['url'] as String;
    final publishedAt = updateInfo['publishedAt'] as String;
    
    // 格式化发布日期
    final DateTime publishDate = DateTime.parse(publishedAt);
    final String formattedDate = '${publishDate.year}-${publishDate.month.toString().padLeft(2, '0')}-${publishDate.day.toString().padLeft(2, '0')}';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDownloading = false;
        double progress = 0.0;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('发现新版本 $version'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('发布日期: $formattedDate'),
                    const SizedBox(height: 16),
                    const Text(
                      '更新内容:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(notes),
                    if (isDownloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text('下载进度: ${(progress * 100).toStringAsFixed(1)}%'),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('稍后更新'),
                ),
                FilledButton(
                  onPressed: isDownloading 
                    ? null 
                    : () async {
                        setState(() {
                          isDownloading = true;
                        });
                        
                        await downloadAndInstallUpdate(
                          url,
                          onProgress: (value) {
                            setState(() {
                              progress = value;
                            });
                          },
                          onSuccess: () {
                            Navigator.of(context).pop();
                            Fluttertoast.showToast(msg: '更新已下载，请安装');
                          },
                          onError: (error) {
                            setState(() {
                              isDownloading = false;
                            });
                            Fluttertoast.showToast(msg: '更新失败: $error');
                          },
                        );
                      },
                  child: Text(isDownloading ? '下载中...' : '立即更新'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}

// 用于版本比较
class Math {
  static int min(int a, int b) {
    return a < b ? a : b;
  }
} 