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
  static const String _releasesUrl = 'https://github.com/$_owner/$_repo/releases/latest';
  
  // 检查是否有更新
  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      // 获取当前应用版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      
      Logger.d('当前应用版本: $currentVersion+$currentBuildNumber (仅比较语义版本 $currentVersion)', tag: 'AppUpdate');
      
      // 请求GitHub API获取最新发布版本
      // 添加必要的请求头，避免GitHub API限制
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'strava_pro_app',  // 添加User-Agent头以避免403错误
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      
      Logger.d('GitHub API请求状态码: ${response.statusCode}', tag: 'AppUpdate');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String? ?? '';
        
        // 输出完整的响应以便调试
        Logger.d('GitHub API响应: ${response.body}', tag: 'AppUpdate');
        
        // 移除版本号前的'v'前缀(如果有)
        final cleanLatestVersion = latestVersion.startsWith('v') 
            ? latestVersion.substring(1) 
            : latestVersion;
            
        Logger.d('GitHub最新版本: $cleanLatestVersion', tag: 'AppUpdate');
        
        // 处理版本检查和返回结果...
        return await _processVersionCheck(data, cleanLatestVersion, currentVersion, currentBuildNumber);
      } else {
        // 处理不同的错误情况
        if (response.statusCode == 403) {
          if (response.headers.containsKey('x-ratelimit-remaining') && 
              int.tryParse(response.headers['x-ratelimit-remaining'] ?? '0') == 0) {
            // API请求限制已达上限
            Logger.e('GitHub API请求已达限制，剩余限制: ${response.headers['x-ratelimit-remaining']}, '
                '重置时间: ${response.headers['x-ratelimit-reset']}', tag: 'AppUpdate');
          } else {
            // 其他403原因，可能是缺少User-Agent等
            Logger.e('GitHub API访问被拒绝(403): ${response.body}\n'
                '请求头: ${response.request?.headers}', tag: 'AppUpdate');
          }
        } else if (response.statusCode == 404) {
          Logger.e('GitHub仓库或发布版本未找到(404)', tag: 'AppUpdate');
        } else {
          Logger.e('GitHub API请求失败: ${response.statusCode}, 响应: ${response.body}', tag: 'AppUpdate');
        }
        
        // 尝试使用备用方法获取更新信息
        Logger.d('尝试使用备用方法获取发布信息...', tag: 'AppUpdate');
        return await _getReleaseFallback(currentVersion, currentBuildNumber);
      }
    } catch (e) {
      Logger.e('检查更新时出错', error: e, tag: 'AppUpdate');
      return null;
    }
  }
  
  // 处理版本检查逻辑
  Future<Map<String, dynamic>?> _processVersionCheck(
    Map<String, dynamic> data, 
    String cleanLatestVersion, 
    String currentVersion, 
    int currentBuildNumber
  ) async {
    // 版本格式处理改进：主要提取语义版本号部分
    String latestSemanticVersion;
    int latestBuildNumber;
    
    // 尝试分离版本号和构建号
    List<String> versionParts = cleanLatestVersion.split('+');
    if (versionParts.length == 2) {
      // 标准格式：x.y.z+123
      latestSemanticVersion = versionParts[0];
      latestBuildNumber = int.tryParse(versionParts[1]) ?? 0;
    } else {
      // 尝试其他格式：可能是纯语义版本号
      latestSemanticVersion = cleanLatestVersion;
      
      // 获取assets中的APK文件名，可能包含构建号
      final assets = data['assets'] as List<dynamic>? ?? [];
      int? buildFromAsset;
      
      for (var asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          // 尝试从文件名提取构建号
          final match = RegExp(r'.*?[\+_](\d+)\.apk$').firstMatch(name);
          if (match != null && match.groupCount >= 1) {
            buildFromAsset = int.tryParse(match.group(1) ?? '');
            if (buildFromAsset != null) {
              break;
            }
          }
        }
      }
      
      // 如果从资源中找到构建号，使用它；否则使用发布ID作为构建号
      latestBuildNumber = buildFromAsset ?? (data['id'] as int? ?? 0);
    }
    
    Logger.d('解析后版本: 语义版本=$latestSemanticVersion, 构建号=$latestBuildNumber', tag: 'AppUpdate');
    
    // 比较版本号（只比较语义版本号，忽略构建号）
    bool hasUpdate = false;
    
    // 首先比较语义版本
    List<String> currentParts = currentVersion.split('.');
    List<String> latestParts = latestSemanticVersion.split('.');
    
    for (int i = 0; i < Math.min(currentParts.length, latestParts.length); i++) {
      int currentPart = int.tryParse(currentParts[i]) ?? 0;
      int latestPart = int.tryParse(latestParts[i]) ?? 0;
      
      Logger.d('比较版本部分: 当前[$i]=$currentPart, 最新[$i]=$latestPart', tag: 'AppUpdate');
      
      if (latestPart > currentPart) {
        hasUpdate = true;
        Logger.d('发现语义版本更新: $currentPart < $latestPart', tag: 'AppUpdate');
        break;
      } else if (latestPart < currentPart) {
        Logger.d('当前语义版本更新: $currentPart > $latestPart', tag: 'AppUpdate');
        return null; // 本地版本更高
      }
    }
    
    // 只有在语义版本完全相同的情况下才考虑构建号（这一部分代码可选，取决于你的需求）
    // 如果你只想比较语义版本号，可以直接删除下面这段代码
    /*
    if (!hasUpdate) {
      Logger.d('语义版本相同，比较构建号: 当前=$currentBuildNumber, 最新=$latestBuildNumber', tag: 'AppUpdate');
      if (latestBuildNumber > currentBuildNumber) {
        hasUpdate = true;
        Logger.d('发现构建号更新: $currentBuildNumber < $latestBuildNumber', tag: 'AppUpdate');
      }
    }
    */
    
    if (hasUpdate) {
      // 拼接完整版本号用于显示
      final displayVersion = latestSemanticVersion; // 只显示语义版本号
      Logger.d('检测到新版本: $displayVersion', tag: 'AppUpdate');
      
      // 返回更新信息
      return {
        'version': displayVersion,
        'notes': data['body'] as String? ?? '无更新说明',
        'url': _getApkDownloadUrl(data),
        'publishedAt': data['published_at'] as String? ?? '',
      };
    } else {
      Logger.d('没有可用更新', tag: 'AppUpdate');
    }
    
    return null;
  }
  
  // 备用方法：直接使用GitHub发布页面URL
  Future<Map<String, dynamic>?> _getReleaseFallback(String currentVersion, int currentBuildNumber) async {
    // 当API调用失败时，我们提供一个备用选项，直接前往GitHub发布页面
    try {
      // 由于无法直接获取版本号，我们为用户创建一个指向最新发布页面的链接
      // 展示固定文案，提示有新版本可用
      Logger.d('使用备用方法提供GitHub发布页面链接', tag: 'AppUpdate');
      
      return {
        'version': '最新版本', // 我们无法获知具体版本号
        'notes': '无法获取具体更新内容，请访问GitHub查看详情。',
        'url': _releasesUrl, // 直接指向GitHub发布页面
        'publishedAt': DateTime.now().toIso8601String(), // 使用当前时间
      };
    } catch (e) {
      Logger.e('备用方法获取更新信息也失败了', error: e, tag: 'AppUpdate');
      return null;
    }
  }
  
  // 获取APK下载URL
  String _getApkDownloadUrl(Map<String, dynamic> releaseData) {
    final assets = releaseData['assets'] as List<dynamic>? ?? [];
    
    // 首先尝试查找APK文件
    for (var asset in assets) {
      final name = asset['name'] as String? ?? '';
      if (name.endsWith('.apk')) {
        final downloadUrl = asset['browser_download_url'] as String? ?? '';
        if (downloadUrl.isNotEmpty) {
          Logger.d('找到APK下载链接: $downloadUrl', tag: 'AppUpdate');
          return downloadUrl;
        }
      }
    }
    
    // 如果没有找到APK资源，返回发布页面URL
    Logger.d('未找到APK资源，使用发布页面URL', tag: 'AppUpdate');
    return _releasesUrl;
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
    
    // 判断是否是备用更新方式（直接打开GitHub页面）
    final bool isFallbackMode = version == '最新版本';
    
    // 格式化发布日期
    String formattedDate;
    try {
      final DateTime publishDate = DateTime.parse(publishedAt);
      formattedDate = '${publishDate.year}-${publishDate.month.toString().padLeft(2, '0')}-${publishDate.day.toString().padLeft(2, '0')}';
    } catch (e) {
      formattedDate = '未知';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isDownloading = false;
        double progress = 0.0;
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isFallbackMode ? '有新版本可用' : '发现新版本 $version'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isFallbackMode) Text('发布日期: $formattedDate'),
                    const SizedBox(height: 16),
                    const Text(
                      '更新内容:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(notes),
                    if (isFallbackMode) 
                      const Text(
                        '\n由于GitHub API限制，无法直接检查更新，请点击"查看更新"前往GitHub页面手动下载最新版本。',
                        style: TextStyle(color: Colors.orange),
                      ),
                    if (isDownloading && !isFallbackMode) ...[
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
                        if (isFallbackMode) {
                          // 直接打开GitHub页面
                          if (await canLaunchUrl(Uri.parse(url))) {
                            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                            Navigator.of(context).pop();
                          } else {
                            Fluttertoast.showToast(msg: '无法打开链接: $url');
                          }
                        } else {
                          // 常规下载流程
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
                        }
                      },
                  child: Text(isFallbackMode 
                    ? '查看更新' 
                    : (isDownloading ? '下载中...' : '立即更新')),
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