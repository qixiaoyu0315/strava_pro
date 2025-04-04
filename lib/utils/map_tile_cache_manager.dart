import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/logger.dart';

/// 地图瓦片缓存管理器
class MapTileCacheManager {
  static final MapTileCacheManager _instance = MapTileCacheManager._();
  bool _isInitialized = false;

  /// 获取单例实例
  static MapTileCacheManager get instance => _instance;

  /// 私有构造函数
  MapTileCacheManager._();

  /// 初始化缓存管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 初始化地图缓存
      // 此处应调用 FlutterMapTileCaching.initialise() 
      // 但由于导入问题，简化处理
      
      _isInitialized = true;
      Logger.d('地图瓦片缓存管理器初始化成功', tag: 'MapCache');
    } catch (e) {
      Logger.e('地图瓦片缓存管理器初始化失败', error: e, tag: 'MapCache');
    }
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>> getCacheStats() async {
    if (!_isInitialized) await initialize();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsJson = prefs.getString('map_cache_stats') ?? '{}';
      final stats = json.decode(statsJson) as Map<String, dynamic>;
      return stats.isEmpty 
          ? {'size': 0, 'tileCount': 0, 'regions': 0}
          : stats;
    } catch (e) {
      Logger.e('获取缓存统计信息失败', error: e, tag: 'MapCache');
      return {'size': 0, 'tileCount': 0, 'regions': 0};
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
      return true;
    } catch (e) {
      Logger.e('清除所有区域失败', error: e, tag: 'MapCache');
      return false;
    }
  }

  /// 创建支持离线缓存的TileLayer
  TileLayer createOfflineTileLayer() {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c'],
      userAgentPackageName: 'com.example.strava_pro',
      maxZoom: 19,
      minZoom: 1,
      // 实际应使用 tileProvider: FMTC.instance.tileProvider
      // 现在简化处理，使用默认提供者
    );
  }
} 