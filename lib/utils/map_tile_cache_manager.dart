import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/logger.dart';

/// 地图瓦片缓存管理器 - 简单缓存实现
class MapTileCacheManager {
  static final MapTileCacheManager _instance = MapTileCacheManager._();
  bool _isInitialized = false;
  Directory? _cacheDir;

  /// 获取单例实例
  static MapTileCacheManager get instance => _instance;

  /// 私有构造函数
  MapTileCacheManager._();

  /// 初始化缓存管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 获取缓存目录
      final appDir = await getApplicationDocumentsDirectory();
      _cacheDir = Directory('${appDir.path}/map_tiles_cache');
      
      // 确保缓存目录存在
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      _isInitialized = true;
      Logger.d('地图瓦片缓存管理器初始化成功，缓存路径: ${_cacheDir!.path}', tag: 'MapCache');
    } catch (e) {
      Logger.e('地图瓦片缓存管理器初始化失败', error: e, tag: 'MapCache');
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_isInitialized) await initialize();
    
    try {
      // 计算缓存大小和数量
      int size = 0;
      int tileCount = 0;
      
      if (_cacheDir != null && await _cacheDir!.exists()) {
        final files = await _cacheDir!.list(recursive: true)
            .where((entity) => entity is File)
            .cast<File>()
            .toList();
            
        for (var file in files) {
          if (file.path.endsWith('.png')) {
            final fileSize = await file.length();
            size += fileSize;
            tileCount++;
          }
        }
      }
      
      final regions = await getSavedRegions();
      
      // 更新缓存统计并保存
      final stats = {
        'size': size,
        'tileCount': tileCount,
        'regions': regions.length,
        'lastUpdated': DateTime.now().millisecondsSinceEpoch,
      };
      
      // 保存最新的统计数据
      await saveCacheStats(stats);
      
      return stats;
    } catch (e) {
      Logger.e('获取缓存统计信息失败', error: e, tag: 'MapCache');
      return {'size': 0, 'tileCount': 0, 'regions': 0, 'lastUpdated': DateTime.now().millisecondsSinceEpoch};
    }
  }
  
  /// 保存缓存统计信息
  Future<void> saveCacheStats(Map<String, dynamic> stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('map_cache_stats', json.encode(stats));
      Logger.d('保存缓存统计信息成功', tag: 'MapCache');
    } catch (e) {
      Logger.e('保存缓存统计信息失败', error: e, tag: 'MapCache');
    }
  }

  /// 获取已保存的区域信息
  Future<Map<String, dynamic>> getSavedRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final regionsJson = prefs.getString('map_cache_regions') ?? '{}';
      return json.decode(regionsJson) as Map<String, dynamic>;
    } catch (e) {
      Logger.e('获取已保存区域信息失败', error: e, tag: 'MapCache');
      return {};
    }
  }
  
  /// 保存区域信息
  Future<void> saveRegions(Map<String, dynamic> regions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('map_cache_regions', json.encode(regions));
      
      // 检查缓存目录是否初始化
      if (_cacheDir == null) {
        Logger.w('保存区域信息: 缓存目录未初始化', tag: 'MapCache');
        return;
      }
      
      // 同时更新缓存统计
      int totalSize = 0;
      int totalTileCount = 0;
      int regionCount = regions.length;
      
      regions.forEach((_, value) {
        final regionInfo = value as Map<String, dynamic>;
        totalSize += (regionInfo['size'] as int?) ?? 0;
        totalTileCount += (regionInfo['tileCount'] as int?) ?? 0;
      });
      
      await saveCacheStats({
        'size': totalSize,
        'tileCount': totalTileCount,
        'regions': regionCount,
      });
      
      Logger.d('保存区域信息成功，包含 $regionCount 个区域', tag: 'MapCache');
    } catch (e) {
      Logger.e('保存区域信息失败', error: e, tag: 'MapCache');
    }
  }
  
  /// 删除指定区域
  Future<bool> deleteRegion(String regionName) async {
    try {
      final regions = await getSavedRegions();
      if (!regions.containsKey(regionName)) {
        return false;
      }
      
      regions.remove(regionName);
      await saveRegions(regions);
      return true;
    } catch (e) {
      Logger.e('删除区域失败', error: e, tag: 'MapCache');
      return false;
    }
  }
  
  /// 清除所有缓存区域
  Future<bool> clearAllRegions() async {
    try {
      await saveRegions({});
      
      // 清除所有瓦片文件
      if (_isInitialized && _cacheDir != null) {
        if (await _cacheDir!.exists()) {
          await _cacheDir!.delete(recursive: true);
          await _cacheDir!.create(recursive: true);
          Logger.d('已清除所有瓦片缓存文件', tag: 'MapCache');
        }
      }
      
      return true;
    } catch (e) {
      Logger.e('清除所有区域失败', error: e, tag: 'MapCache');
      return false;
    }
  }

  /// 创建TileLayer，使用离线优先的图层
  TileLayer createOfflineTileLayer() {
    // 异步初始化，确保目录存在
    if (!_isInitialized) {
      initialize();
    }
    
    // 如果缓存目录未初始化，使用临时目录
    final cacheDirectory = _cacheDir ?? Directory.systemTemp;
    
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c'],
      userAgentPackageName: 'com.example.strava_pro',
      maxZoom: 19,
      minZoom: 1,
      tileProvider: OfflineFirstTileProvider(
        cacheDir: cacheDirectory,
        onError: (error, stackTrace) {
          Logger.e('加载瓦片出错', error: error, tag: 'MapTile');
        },
      ),
    );
  }
  
  /// 下载指定边界内的瓦片
  Future<void> downloadTiles({
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
    Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();
    
    // 确保缓存目录已初始化
    if (_cacheDir == null) {
      throw Exception('缓存目录未初始化');
    }
    
    try {
      Logger.d('开始下载瓦片区域：${bounds.toString()}, 缩放级别: $minZoom-$maxZoom',
             tag: 'MapCache');
      
      // 计算需要下载的瓦片总数
      int totalTiles = 0;
      List<Map<String, int>> allTiles = [];
      
      for (int z = minZoom; z <= maxZoom; z++) {
        final tiles = _getTilesInBounds(bounds, z);
        totalTiles += tiles.length;
        allTiles.addAll(tiles);
      }
      
      Logger.d('预计下载瓦片数: $totalTiles', tag: 'MapCache');
      
      // 开始下载
      int completedTiles = 0;
      int failedTiles = 0;
      
      final client = http.Client();
      try {
        for (var tile in allTiles) {
          try {
            final success = await _downloadTile(tile, client);
            completedTiles += success ? 1 : 0;
            failedTiles += success ? 0 : 1;
            
            final progress = completedTiles / totalTiles;
            onProgress?.call(progress);
            
            if (completedTiles % 10 == 0 || completedTiles == totalTiles) {
              Logger.d('下载进度: ${(progress * 100).toStringAsFixed(2)}%, '
                       '完成: $completedTiles/$totalTiles, 失败: $failedTiles',
                       tag: 'MapCache');
            }
          } catch (e) {
            failedTiles += 1;
            Logger.e('瓦片下载失败: $tile', error: e, tag: 'MapCache');
          }
        }
      } finally {
        client.close();
      }
      
      Logger.d('瓦片下载完成, 成功: $completedTiles, 失败: $failedTiles', tag: 'MapCache');
      
      // 保存区域信息
      final regionName = "区域_${DateTime.now().millisecondsSinceEpoch}";
      final regions = await getSavedRegions();
      regions[regionName] = {
        'name': regionName,
        'date': DateTime.now().toString(),
        'bounds': {
          'north': bounds.north,
          'south': bounds.south,
          'east': bounds.east,
          'west': bounds.west,
        },
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'tileCount': completedTiles,
        'size': await _calculateCacheSize(),
      };
      
      await saveRegions(regions);
    } catch (e) {
      Logger.e('下载瓦片失败', error: e, tag: 'MapCache');
      rethrow;
    }
  }
  
  /// 计算缓存大小
  Future<int> _calculateCacheSize() async {
    int size = 0;
    
    if (_cacheDir != null && await _cacheDir!.exists()) {
      final files = await _cacheDir!.list(recursive: true)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
          
      for (var file in files) {
        if (file.path.endsWith('.png')) {
          size += await file.length();
        }
      }
    }
    
    return size;
  }
  
  /// 计算边界范围内的所有瓦片坐标
  List<Map<String, int>> _getTilesInBounds(LatLngBounds bounds, int zoom) {
    final List<Map<String, int>> result = [];
    
    final minX = _longitudeToTileX(bounds.west, zoom);
    final maxX = _longitudeToTileX(bounds.east, zoom);
    final minY = _latitudeToTileY(bounds.north, zoom);
    final maxY = _latitudeToTileY(bounds.south, zoom);
    
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        result.add({'x': x, 'y': y, 'z': zoom});
      }
    }
    
    return result;
  }
  
  /// 下载单个瓦片
  Future<bool> _downloadTile(Map<String, int> tile, http.Client client) async {
    try {
      final url = _getTileUrl(tile);
      final response = await client.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // 确保缓存目录已初始化
        if (_cacheDir == null) {
          return false;
        }
        
        // 保存瓦片到本地
        final filePath = '${_cacheDir!.path}/${tile['z']}/${tile['x']}/${tile['y']}.png';
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);
        return true;
      } else {
        Logger.e('瓦片下载HTTP错误: ${response.statusCode}', tag: 'MapCache');
        return false;
      }
    } catch (e) {
      Logger.e('下载瓦片失败', error: e, tag: 'MapCache');
      return false;
    }
  }
  
  /// 获取瓦片URL
  String _getTileUrl(Map<String, int> tile) {
    final subdomains = ['a', 'b', 'c'];
    final subdomain = subdomains[tile['x']! % subdomains.length];
    return 'https://$subdomain.tile.openstreetmap.org/${tile['z']}/${tile['x']}/${tile['y']}.png';
  }
  
  /// 经度转瓦片X坐标
  int _longitudeToTileX(double longitude, int zoom) {
    return ((longitude + 180.0) / 360.0 * (1 << zoom)).floor();
  }
  
  /// 纬度转瓦片Y坐标
  int _latitudeToTileY(double latitude, int zoom) {
    final latRad = latitude * (pi / 180.0);
    return ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * (1 << zoom)).floor();
  }
}

/// 离线优先的瓦片提供者
class OfflineFirstTileProvider extends TileProvider {
  final Directory cacheDir;
  final Function(Object error, StackTrace stackTrace)? onError;
  final http.Client _client = http.Client();
  bool _isValid = false;

  OfflineFirstTileProvider({
    required this.cacheDir,
    this.onError,
  }) {
    // 验证缓存目录是否有效
    _isValid = cacheDir.existsSync();
    if (!_isValid) {
      try {
        cacheDir.createSync(recursive: true);
        _isValid = true;
      } catch (e) {
        Logger.e('创建缓存目录失败', error: e, tag: 'MapTile');
      }
    }
  }

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) {
    return OfflineFirstTileImage(
      coordinates: coordinates,
      options: options,
      cacheDir: cacheDir,
      client: _client,
      isValid: _isValid,
      onError: onError,
    );
  }

  @override
  void dispose() {
    _client.close();
  }
}

/// 离线优先的瓦片图片提供者
class OfflineFirstTileImage extends ImageProvider<OfflineFirstTileImage> {
  final TileCoordinates coordinates;
  final TileLayer options;
  final Directory cacheDir;
  final http.Client client;
  final bool isValid;
  final Function(Object error, StackTrace stackTrace)? onError;

  OfflineFirstTileImage({
    required this.coordinates,
    required this.options,
    required this.cacheDir,
    required this.client,
    this.isValid = false,
    this.onError,
  });

  @override
  Future<OfflineFirstTileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<OfflineFirstTileImage>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(
    OfflineFirstTileImage key,
    DecoderBufferCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(
    OfflineFirstTileImage key,
    DecoderBufferCallback decode,
  ) async {
    try {
      // 检查缓存目录是否有效
      if (isValid) {
        // 1. 首先尝试从本地缓存加载
        final filePath = '${cacheDir.path}/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
        final file = File(filePath);
        
        if (await file.exists()) {
          try {
            final bytes = await file.readAsBytes();
            Logger.d('从本地加载瓦片: z=${coordinates.z}, x=${coordinates.x}, y=${coordinates.y}', 
              tag: 'MapTile');
            final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
            return decode(buffer);
          } catch (e, stackTrace) {
            Logger.w('读取本地瓦片失败，尝试从网络加载', error: e, tag: 'MapTile');
            onError?.call(e, stackTrace);
          }
        }
      } else {
        Logger.w('缓存目录无效，跳过本地检查', tag: 'MapTile');
      }

      // 2. 如果本地没有或缓存目录无效，从网络加载
      String url = '';
      if (options.subdomains.isNotEmpty) {
        final subdomain = options.subdomains[coordinates.x % options.subdomains.length];
        url = options.urlTemplate!
            .replaceAll('{s}', subdomain)
            .replaceAll('{z}', coordinates.z.toString())
            .replaceAll('{x}', coordinates.x.toString())
            .replaceAll('{y}', coordinates.y.toString());
      } else {
        url = options.urlTemplate!
            .replaceAll('{z}', coordinates.z.toString())
            .replaceAll('{x}', coordinates.x.toString())
            .replaceAll('{y}', coordinates.y.toString());
      }
      
      Logger.d('从网络加载瓦片: z=${coordinates.z}, x=${coordinates.x}, y=${coordinates.y}', 
            tag: 'MapTile');
          
      final response = await client.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // 只有在缓存目录有效时才尝试保存
        if (isValid) {
          // 异步保存到本地缓存
          try {
            final filePath = '${cacheDir.path}/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
            final file = File(filePath);
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes);
            Logger.d('瓦片已缓存: z=${coordinates.z}, x=${coordinates.x}, y=${coordinates.y}', 
              tag: 'MapTile');
          } catch (e) {
            Logger.w('保存瓦片到本地失败', error: e, tag: 'MapTile');
          }
        }

        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        return decode(buffer);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      onError?.call(e, stackTrace);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is OfflineFirstTileImage &&
        other.coordinates == coordinates &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(coordinates, options);
} 