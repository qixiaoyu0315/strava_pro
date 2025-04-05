import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import '../utils/logger.dart';

/// 路线图片缓存管理器
/// 用于缓存路线卡片上的地图图片，避免重复下载
class RouteImageCacheManager {
  static final RouteImageCacheManager _instance = RouteImageCacheManager._();
  bool _isInitialized = false;
  Directory? _cacheDir;
  final Map<String, Uint8List> _memoryCache = {};
  final Map<String, DateTime> _lastAccessTime = {}; // 记录每个缓存项的最后访问时间
  final int _maxMemoryCacheCount = 100; // 增加内存缓存数量
  final List<String> _cacheKeys = []; // 缓存键列表，用于LRU替换策略
  Timer? _cleanupTimer;

  /// 获取单例实例
  static RouteImageCacheManager get instance => _instance;

  /// 私有构造函数
  RouteImageCacheManager._() {
    // 启动定期清理任务
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanupOldCache());
  }

  /// 初始化缓存管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 获取缓存目录
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/route_images_cache');
      
      // 确保缓存目录存在
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      _isInitialized = true;
      Logger.d('路线图片缓存管理器初始化成功，缓存路径: ${_cacheDir!.path}', tag: 'RouteImageCache');
      
      // 初始化后预加载最近的路线图片到内存
      await _preloadRecentImages();
    } catch (e) {
      Logger.e('路线图片缓存管理器初始化失败', error: e, tag: 'RouteImageCache');
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _memoryCache.clear();
    _lastAccessTime.clear();
    _cacheKeys.clear();
  }
  
  /// 定期清理过期缓存
  Future<void> _cleanupOldCache() async {
    try {
      final now = DateTime.now();
      
      // 清理内存缓存中超过30分钟未访问的项目
      _lastAccessTime.removeWhere((key, lastAccess) {
        if (now.difference(lastAccess).inMinutes > 30) {
          _memoryCache.remove(key);
          _cacheKeys.remove(key);
          return true;
        }
        return false;
      });
      
      // 清理磁盘缓存中超过7天的文件
      if (_cacheDir != null && await _cacheDir!.exists()) {
        final files = await _cacheDir!.list().toList();
        for (var entity in files) {
          if (entity is File) {
            final stat = await entity.stat();
            if (now.difference(stat.modified).inDays > 7) {
              await entity.delete();
            }
          }
        }
      }
    } catch (e) {
      Logger.e('清理缓存失败', error: e, tag: 'RouteImageCache');
    }
  }
  
  /// 预加载最近的路线图片到内存
  Future<void> _preloadRecentImages() async {
    try {
      if (_cacheDir == null || !await _cacheDir!.exists()) return;
      
      final files = await _cacheDir!.list().toList();
      files.sort((a, b) => 
        File(b.path).statSync().modified.compareTo(File(a.path).statSync().modified));
      
      // 预加载最近50张图片到内存
      final preloadCount = min(50, files.length);
      for (int i = 0; i < preloadCount; i++) {
        if (files[i] is File && files[i].path.endsWith('.png')) {
          final file = File(files[i].path);
          final key = file.uri.pathSegments.last.replaceAll('.png', '');
          try {
            final bytes = await file.readAsBytes();
            _addToMemoryCache(key, bytes);
            Logger.d('预加载图片到内存: $key', tag: 'RouteImageCache');
          } catch (e) {
            Logger.e('预加载图片失败: $key', error: e, tag: 'RouteImageCache');
          }
        }
      }
    } catch (e) {
      Logger.e('预加载路线图片失败', error: e, tag: 'RouteImageCache');
    }
  }
  
  /// 清理缓存
  Future<void> clearCache() async {
    try {
      // 清理内存缓存
      _memoryCache.clear();
      _cacheKeys.clear();
      
      // 清理磁盘缓存
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
      
      Logger.d('路线图片缓存已清理', tag: 'RouteImageCache');
    } catch (e) {
      Logger.e('清理路线图片缓存失败', error: e, tag: 'RouteImageCache');
    }
  }
  
  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_isInitialized) await initialize();
    
    try {
      int diskSize = 0;
      int imageCount = 0;
      
      if (_cacheDir != null && await _cacheDir!.exists()) {
        final files = await _cacheDir!.list()
            .where((entity) => entity is File && entity.path.endsWith('.png'))
            .cast<File>()
            .toList();
            
        for (var file in files) {
          final fileSize = await file.length();
          diskSize += fileSize;
          imageCount++;
        }
      }
      
      return {
        'diskSize': diskSize,
        'diskImageCount': imageCount,
        'memoryImageCount': _memoryCache.length,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      Logger.e('获取路线图片缓存统计信息失败', error: e, tag: 'RouteImageCache');
      return {
        'diskSize': 0, 
        'diskImageCount': 0, 
        'memoryImageCount': 0,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch
      };
    }
  }
  
  /// 从URL获取图片
  Future<Uint8List> getImageFromUrl(String url, {bool isDarkMode = false}) async {
    if (!_isInitialized) await initialize();
    
    // 生成缓存键
    final cacheKey = _generateCacheKey(url, isDarkMode);
    
    try {
      // 1. 首先尝试从内存缓存中获取
      if (_memoryCache.containsKey(cacheKey)) {
        // 更新最后访问时间
        _lastAccessTime[cacheKey] = DateTime.now();
        
        // 更新LRU队列
        _cacheKeys.remove(cacheKey);
        _cacheKeys.add(cacheKey);
        
        Logger.d('从内存加载路线图片: $cacheKey', tag: 'RouteImageCache');
        return _memoryCache[cacheKey]!;
      }
      
      // 2. 从磁盘缓存中获取
      if (_cacheDir != null) {
        final file = File('${_cacheDir!.path}/$cacheKey.png');
        if (await file.exists()) {
          try {
            final bytes = await file.readAsBytes();
            // 添加到内存缓存
            _addToMemoryCache(cacheKey, bytes);
            Logger.d('从磁盘加载路线图片: $cacheKey', tag: 'RouteImageCache');
            return bytes;
          } catch (e) {
            Logger.w('读取磁盘缓存图片失败，尝试从网络加载', error: e, tag: 'RouteImageCache');
          }
        }
      }
      
      // 3. 从网络获取
      Logger.d('从网络加载路线图片: $url', tag: 'RouteImageCache');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final bytes = Uint8List.fromList(response.bodyBytes);
        
        // 保存到缓存
        await _saveToCache(cacheKey, bytes);
        
        return bytes;
      } else {
        throw Exception('HTTP错误: ${response.statusCode}');
      }
    } catch (e) {
      Logger.e('获取路线图片失败: $url', error: e, tag: 'RouteImageCache');
      rethrow;
    }
  }
  
  /// 将图片添加到内存缓存
  void _addToMemoryCache(String key, Uint8List bytes) {
    // 如果内存缓存已满，移除最早未使用的项目
    while (_memoryCache.length >= _maxMemoryCacheCount && _cacheKeys.isNotEmpty) {
      final oldestKey = _cacheKeys.removeAt(0);
      _memoryCache.remove(oldestKey);
      _lastAccessTime.remove(oldestKey);
    }
    
    // 添加新图片到内存缓存
    _memoryCache[key] = bytes;
    _lastAccessTime[key] = DateTime.now();
    _cacheKeys.add(key);
  }
  
  /// 保存图片到缓存
  Future<void> _saveToCache(String key, Uint8List bytes) async {
    try {
      // 保存到内存缓存
      _addToMemoryCache(key, bytes);
      
      // 保存到磁盘缓存
      if (_cacheDir != null) {
        final file = File('${_cacheDir!.path}/$key.png');
        await file.writeAsBytes(bytes);
        Logger.d('路线图片已缓存: $key', tag: 'RouteImageCache');
      }
    } catch (e) {
      Logger.e('保存路线图片到缓存失败', error: e, tag: 'RouteImageCache');
    }
  }
  
  /// 根据URL和主题模式生成缓存键
  String _generateCacheKey(String url, bool isDarkMode) {
    final keyString = '$url-${isDarkMode ? 'dark' : 'light'}';
    return md5.convert(utf8.encode(keyString)).toString();
  }
} 