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
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

class AppUpdateService {
  static const String _owner = 'qixiaoyu0315';
  static const String _repo = 'strava_pro';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';
  static const String _releasesUrl = 'https://github.com/$_owner/$_repo/releases/latest';
  static const String _ignoredVersionKey = 'ignored_update_version';
  
  // 检查是否有更新
  Future<Map<String, dynamic>?> checkForUpdate({bool forceCheck = false}) async {
    try {
      // 获取当前应用版本
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.parse(packageInfo.buildNumber);
      
      Logger.d('当前应用版本: $currentVersion+$currentBuildNumber (仅比较语义版本 $currentVersion)', tag: 'AppUpdate');
      
      // 检查是否有被忽略的版本
      if (!forceCheck) {
        final ignoredVersion = await _getIgnoredVersion();
        if (ignoredVersion != null) {
          Logger.d('发现已忽略的版本: $ignoredVersion', tag: 'AppUpdate');
        }
      }
      
      // 请求GitHub API获取最新发布版本
      // 添加必要的请求头，避免GitHub API限制
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'strava_pro_app/$currentVersion',  // 添加版本信息到User-Agent
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
        
        // 检查是否已忽略此版本
        if (!forceCheck) {
          final ignoredVersion = await _getIgnoredVersion();
          if (ignoredVersion != null && _getSemanticVersion(cleanLatestVersion) == ignoredVersion) {
            Logger.d('版本 $ignoredVersion 已被用户忽略，跳过更新检查', tag: 'AppUpdate');
            return null;
          }
        }
        
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
    
    // 尝试分离版本号和构建号
    List<String> versionParts = cleanLatestVersion.split('+');
    if (versionParts.length == 2) {
      // 标准格式：x.y.z+123
      latestSemanticVersion = versionParts[0];
    } else {
      // 尝试其他格式：可能是纯语义版本号
      latestSemanticVersion = cleanLatestVersion;
    }
    
    Logger.d('版本比较: 本地版本=${currentVersion}, GitHub版本=${latestSemanticVersion}', tag: 'AppUpdate');
    
    // 如果版本号完全相同，直接返回null（没有更新）
    if (currentVersion == latestSemanticVersion) {
      Logger.d('版本号完全相同，无需更新', tag: 'AppUpdate');
      return null;
    }
    
    // 比较版本号（只比较语义版本号，忽略构建号）
    bool hasUpdate = false;
    
    // 首先比较语义版本
    List<String> currentParts = currentVersion.split('.');
    List<String> latestParts = latestSemanticVersion.split('.');
    
    // 确保两个版本号都有足够的部分进行比较
    while (currentParts.length < 3) currentParts.add('0');
    while (latestParts.length < 3) latestParts.add('0');
    
    for (int i = 0; i < 3; i++) { // 通常只比较前三部分：主要版本、次要版本和补丁版本
      int currentPart = int.tryParse(currentParts[i]) ?? 0;
      int latestPart = int.tryParse(latestParts[i]) ?? 0;
      
      Logger.d('比较版本部分[$i]: 本地=$currentPart, GitHub=$latestPart', tag: 'AppUpdate');
      
      if (latestPart > currentPart) {
        hasUpdate = true;
        Logger.d('发现更新: $currentPart < $latestPart', tag: 'AppUpdate');
        break;
      } else if (latestPart < currentPart) {
        Logger.d('本地版本更高: $currentPart > $latestPart', tag: 'AppUpdate');
        return null; // 本地版本更高
      }
      // 如果相等则继续比较下一部分
    }
    
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
      // 获取外部存储目录用于保存APK，确保有足够的权限
      Directory? directory;
      String savePath = '';
      
      try {
        if (Platform.isAndroid) {
          // 在Android上，尝试使用外部存储的Download目录
          directory = Directory('/storage/emulated/0/Download');
          if (!(await directory.exists())) {
            // 如果不存在，尝试创建
            await directory.create(recursive: true);
          }
          savePath = '${directory.path}/strava_pro_update.apk';
          Logger.d('保存APK到下载目录: $savePath', tag: 'AppUpdate');
        } else {
          // 其他平台使用临时目录
          directory = await getTemporaryDirectory();
          savePath = '${directory.path}/strava_pro_update.apk';
          Logger.d('保存APK到临时目录: $savePath', tag: 'AppUpdate');
        }
      } catch (e) {
        // 如果获取外部存储失败，回退到应用缓存目录
        Logger.w('无法访问下载目录，使用应用缓存目录', error: e, tag: 'AppUpdate');
        directory = await getTemporaryDirectory();
        savePath = '${directory.path}/strava_pro_update.apk';
      }
      
      // 显示开始下载的消息
      Logger.d('开始从 $url 下载APK到 $savePath', tag: 'AppUpdate');
      
      // 使用Dio下载文件
      final dio = Dio();
      await dio.download(
        url, 
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            final progress = received / total;
            onProgress(progress);
            if (progress % 0.1 < 0.01) { // 每10%记录一次日志
              Logger.d('下载进度: ${(progress * 100).toStringAsFixed(1)}%', tag: 'AppUpdate');
            }
          }
        },
      );
      
      Logger.d('APK下载完成: $savePath', tag: 'AppUpdate');
      
      // 安装APK
      if (Platform.isAndroid) {
        final apkFile = File(savePath);
        if (await apkFile.exists()) {
          Logger.d('APK文件存在，准备启动安装', tag: 'AppUpdate');
          
          try {
            // 使用FileProvider创建内容URI
            Uri contentUri;
            
            // 使用特定的URI格式，确保能够访问文件
            String uriStr = 'content://com.example.strava_pro.fileprovider';
            
            if (savePath.startsWith('/storage/emulated/0/Download')) {
              // 如果是下载目录，使用external-path
              uriStr += '/external_files/${savePath.replaceFirst('/storage/emulated/0/', '')}';
              Logger.d('使用external-path创建URI: $uriStr', tag: 'AppUpdate');
            } else {
              // 如果是缓存目录，使用cache-path
              uriStr += '/cache/${savePath.split('/').last}';
              Logger.d('使用cache-path创建URI: $uriStr', tag: 'AppUpdate');
            }
            
            contentUri = Uri.parse(uriStr);
            
            Logger.d('尝试使用FileProvider URI打开APK: $contentUri', tag: 'AppUpdate');
            if (await canLaunchUrl(contentUri)) {
              final launched = await launchUrl(
                contentUri,
                mode: LaunchMode.externalApplication,
              );
              
              if (launched) {
                Logger.d('成功启动APK安装程序', tag: 'AppUpdate');
                if (onSuccess != null) onSuccess();
                return true;
              } else {
                throw Exception('无法启动安装程序');
              }
            } else {
              // 回退到传统的文件URI方式
              Logger.w('无法使用FileProvider，尝试直接使用文件URI', tag: 'AppUpdate');
              
              final fileUri = Uri.file(savePath);
              if (await canLaunchUrl(fileUri)) {
                final launched = await launchUrl(
                  fileUri,
                  mode: LaunchMode.externalApplication,
                );
                
                if (launched) {
                  Logger.d('使用文件URI成功启动APK安装程序', tag: 'AppUpdate');
                  if (onSuccess != null) onSuccess();
                  return true;
                } else {
                  throw Exception('无法使用文件URI启动安装程序');
                }
              } else {
                throw Exception('无法打开文件URI');
              }
            }
          } catch (e) {
            final error = '无法安装APK: $e';
            Logger.e(error, tag: 'AppUpdate');
            
            // 向用户提供备用选项
            Logger.d('向用户提供手动安装选项', tag: 'AppUpdate');
            if (onError != null) onError('无法自动安装APK，请手动前往下载目录安装:\n$savePath');
            return false;
          }
        } else {
          final error = 'APK文件不存在: $savePath';
          Logger.e(error, tag: 'AppUpdate');
          if (onError != null) onError(error);
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
  
  // 保存忽略的版本
  Future<void> _saveIgnoredVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ignoredVersionKey, _getSemanticVersion(version));
    Logger.d('已将版本 ${_getSemanticVersion(version)} 设置为忽略', tag: 'AppUpdate');
  }
  
  // 重置忽略的版本
  Future<void> resetIgnoredVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ignoredVersionKey);
    Logger.d('已重置忽略的版本', tag: 'AppUpdate');
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
        String? errorMessage;
        
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
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      if (Platform.isAndroid && errorMessage!.contains('下载目录'))
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _openDownloadFolder(),
                            icon: const Icon(Icons.folder_open),
                            label: const Text('打开下载目录'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (!isFallbackMode)
                  TextButton(
                    onPressed: () async {
                      // 忽略这个版本
                      await _saveIgnoredVersion(version);
                      Fluttertoast.showToast(msg: '已忽略版本 $version');
                      Navigator.of(context).pop();
                    },
                    child: const Text('忽略此版本'),
                  ),
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
                            errorMessage = null;
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
                                errorMessage = error;
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
  
  // 打开下载文件夹
  Future<void> _openDownloadFolder() async {
    try {
      if (Platform.isAndroid) {
        final directory = '/storage/emulated/0/Download';
        final directoryUri = Uri.parse('content://com.android.externalstorage.documents/document/primary%3ADownload');
        
        Logger.d('尝试打开下载目录: $directoryUri', tag: 'AppUpdate');
        
        if (await canLaunchUrl(directoryUri)) {
          await launchUrl(directoryUri);
          Logger.d('成功打开下载目录', tag: 'AppUpdate');
        } else {
          // 尝试其他方式
          final fileUri = Uri.directory(directory);
          if (await canLaunchUrl(fileUri)) {
            await launchUrl(fileUri);
            Logger.d('使用file URI打开下载目录', tag: 'AppUpdate');
          } else {
            Logger.e('无法打开下载目录', tag: 'AppUpdate');
            Fluttertoast.showToast(msg: '无法打开下载目录，请手动导航到"下载"文件夹');
          }
        }
      }
    } catch (e) {
      Logger.e('打开下载目录时出错', error: e, tag: 'AppUpdate');
      Fluttertoast.showToast(msg: '无法打开下载目录: $e');
    }
  }
  
  // 获取被忽略的版本
  Future<String?> _getIgnoredVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ignoredVersionKey);
  }
  
  // 获取语义版本
  String _getSemanticVersion(String version) {
    final parts = version.split('+');
    if (parts.length > 0) {
      return parts[0];
    } else {
      throw Exception('无法解析版本格式');
    }
  }
}

// 用于版本比较
class Math {
  static int min(int a, int b) {
    return a < b ? a : b;
  }
} 