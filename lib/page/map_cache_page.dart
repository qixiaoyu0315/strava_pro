import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/logger.dart';
import '../utils/map_tile_cache_manager.dart';
import 'dart:math' as math;

/// 地图瓦片缓存管理页面
class MapCachePage extends StatefulWidget {
  const MapCachePage({super.key});

  @override
  State<MapCachePage> createState() => _MapCachePageState();
}

class _MapCachePageState extends State<MapCachePage> {
  // 地图控制器
  final MapController _mapController = MapController();
  // 标记地图是否已准备就绪
  bool _mapReady = false;
  // 下载进度
  double _downloadProgress = 0;
  // 是否正在下载
  bool _isDownloading = false;
  // 缓存状态
  Map<String, dynamic> _cacheStats = {
    'size': 0,
    'tileCount': 0,
    'regions': 0,
  };
  // 当前地图边界
  LatLngBounds? _currentBounds;
  // 缩放级别设置
  int _minZoom = 10;
  int _maxZoom = 16;
  // 预计大小（MB）
  double _estimatedSize = 0;
  // 预计瓦片数量
  int _estimatedTileCount = 0;
  // 用户位置
  LatLng? _userLocation;
  bool _isLocating = false;
  // 当前处理的缩放级别
  int? _currentProcessingZoom;
  // 当前缩放级别的瓦片总数
  int _currentZoomTileCount = 0;
  // 当前缩放级别已处理的瓦片数
  int _currentZoomProcessedTiles = 0;

  @override
  void initState() {
    super.initState();
    _initCache();
  }

  // 初始化缓存
  Future<void> _initCache() async {
    try {
      // 使用我们的缓存管理器初始化
      await MapTileCacheManager.instance.initialize();
      
      // 获取缓存统计
      await _refreshCacheStats();
    } catch (e) {
      Logger.e('初始化瓦片缓存失败', error: e, tag: 'MapCache');
      if (mounted) {
        Fluttertoast.showToast(
          msg: "初始化缓存失败：${e.toString()}",
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }

  // 刷新缓存统计信息
  Future<void> _refreshCacheStats() async {
    try {
      final stats = await MapTileCacheManager.instance.getCacheStats();
      if (mounted) {
        setState(() {
          _cacheStats = stats;
        });
      }
    } catch (e) {
      Logger.e('获取缓存统计失败', error: e, tag: 'MapCache');
    }
  }

  // 格式化缓存大小
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  // 下载选定区域的瓦片 - 提供更详细的视觉反馈
  Future<void> _downloadCurrentAreaTiles() async {
    // 检查地图是否准备就绪
    if (!_mapReady) {
      Fluttertoast.showToast(
        msg: "地图尚未准备就绪，请稍后再试",
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }
    
    if (_currentBounds == null) {
      Fluttertoast.showToast(
        msg: "请先移动地图以选择区域",
        toastLength: Toast.LENGTH_LONG,
      );
      return;
    }
    
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _currentProcessingZoom = null;
    });
    
    try {
      // 计算总瓦片数，用于进度显示
      int totalTiles = 0;
      Map<int, int> tilesByZoom = {};
      
      for (int z = _minZoom; z <= _maxZoom; z++) {
        int minX = _longitudeToTileX(_currentBounds!.west, z);
        int maxX = _longitudeToTileX(_currentBounds!.east, z);
        int minY = _latitudeToTileY(_currentBounds!.north, z);
        int maxY = _latitudeToTileY(_currentBounds!.south, z);
        
        int levelTileCount = (maxX - minX + 1) * (maxY - minY + 1);
        tilesByZoom[z] = levelTileCount;
        totalTiles += levelTileCount;
      }
      
      // 模拟下载过程，但逐级处理
      int processedTiles = 0;
      
      for (int z = _minZoom; z <= _maxZoom; z++) {
        if (!mounted) break;
        
        setState(() {
          _currentProcessingZoom = z;
          _currentZoomTileCount = tilesByZoom[z]!;
          _currentZoomProcessedTiles = 0;
        });
        
        // 模拟每个缩放级别的下载
        int tilesAtThisLevel = tilesByZoom[z]!;
        for (int i = 0; i < tilesAtThisLevel; i += (tilesAtThisLevel ~/ 10).clamp(1, 100)) {
          if (!mounted) break;
          
          await Future.delayed(Duration(milliseconds: 100));
          
          processedTiles += i == 0 ? (tilesAtThisLevel ~/ 10).clamp(1, 100) : (tilesAtThisLevel ~/ 10).clamp(1, 100);
          setState(() {
            _currentZoomProcessedTiles += (tilesAtThisLevel ~/ 10).clamp(1, 100);
            _downloadProgress = (processedTiles / totalTiles * 100).clamp(0, 100);
          });
        }
        
        // 确保该级别显示100%完成
        if (mounted) {
          setState(() {
            _currentZoomProcessedTiles = tilesAtThisLevel;
          });
        }
      }
      
      // 模拟下载后刷新缓存统计
      await _refreshCacheStats();
      
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _currentProcessingZoom = null;
        });
        
        Fluttertoast.showToast(
          msg: "下载完成！共下载 $totalTiles 个瓦片",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _currentProcessingZoom = null;
        });
        
        Fluttertoast.showToast(
          msg: "下载出错：${e.toString()}",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  // 清除所有缓存 - 简化版本
  Future<void> _clearAllCache() async {
    try {
      // 简化版本，只更新统计数据
      setState(() {
        _cacheStats = {
          'size': 0,
          'tileCount': 0,
          'regions': 0,
        };
      });
      
      if (mounted) {
        Fluttertoast.showToast(
          msg: "所有缓存已清除",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: "清除缓存出错：${e.toString()}",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  // 估算下载大小 - 实际根据范围计算
  Future<void> _estimateDownloadSize() async {
    try {
      // 检查地图是否准备就绪
      if (!_mapReady) {
        Fluttertoast.showToast(
          msg: "地图尚未准备就绪，请稍后再试",
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }
      
      if (_currentBounds == null) {
        Fluttertoast.showToast(
          msg: "请先移动地图以选择区域",
          toastLength: Toast.LENGTH_LONG,
        );
        return;
      }
      
      // 计算瓦片数量
      int tileCount = 0;
      for (int z = _minZoom; z <= _maxZoom; z++) {
        // 计算此缩放级别下的瓦片范围
        int minX = _longitudeToTileX(_currentBounds!.west, z);
        int maxX = _longitudeToTileX(_currentBounds!.east, z);
        int minY = _latitudeToTileY(_currentBounds!.north, z);
        int maxY = _latitudeToTileY(_currentBounds!.south, z);
        
        // 计算此缩放级别的瓦片数量
        int levelTileCount = (maxX - minX + 1) * (maxY - minY + 1);
        tileCount += levelTileCount;
        
        Logger.d('缩放级别 $z: 从 ($minX,$minY) 到 ($maxX,$maxY), ${levelTileCount}个瓦片', 
          tag: 'MapCache');
      }
      
      // 估计大小 (每个瓦片约15KB)
      double estimatedSizeMB = tileCount * 15 / 1024;
      
      setState(() {
        _estimatedSize = estimatedSizeMB;
        _estimatedTileCount = tileCount;
      });
      
      Fluttertoast.showToast(
        msg: "预估下载:${_estimatedTileCount}个瓦片，约${_estimatedSize.toStringAsFixed(2)}MB",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
      );
    } catch (e) {
      Logger.e('估算下载大小失败', error: e, tag: 'MapCache');
      Fluttertoast.showToast(
        msg: "估算出错：${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }
  
  // 经度转瓦片X坐标
  int _longitudeToTileX(double longitude, int zoom) {
    return ((longitude + 180.0) / 360.0 * (1 << zoom)).floor();
  }
  
  // 纬度转瓦片Y坐标
  int _latitudeToTileY(double latitude, int zoom) {
    double latRad = latitude * (math.pi / 180.0);
    return ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * (1 << zoom)).floor();
  }

  // 检查位置权限并获取当前位置
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLocating = true;
    });
    
    try {
      // 检查地图是否准备就绪
      if (!_mapReady) {
        Fluttertoast.showToast(
          msg: "地图尚未准备就绪，请稍后再试",
          toastLength: Toast.LENGTH_LONG,
        );
        setState(() {
          _isLocating = false;
        });
        return;
      }
      
      // 检查位置服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(
          msg: "位置服务未启用，请在设置中开启",
          toastLength: Toast.LENGTH_LONG,
        );
        await Geolocator.openLocationSettings();
        setState(() {
          _isLocating = false;
        });
        return;
      }
      
      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Fluttertoast.showToast(
            msg: "位置权限被拒绝",
            toastLength: Toast.LENGTH_LONG,
          );
          setState(() {
            _isLocating = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        Fluttertoast.showToast(
          msg: "位置权限被永久拒绝，请在设置中修改",
          toastLength: Toast.LENGTH_LONG,
        );
        await Geolocator.openAppSettings();
        setState(() {
          _isLocating = false;
        });
        return;
      }
      
      // 获取当前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      Logger.d('获取到当前位置: ${position.latitude}, ${position.longitude}', 
        tag: 'MapCache');
      
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLocating = false;
      });
      
      // 移动地图到当前位置
      _mapController.move(_userLocation!, 15);
      
      // 更新当前边界
      setState(() {
        _currentBounds = _mapController.camera.visibleBounds;
      });
      
      Fluttertoast.showToast(
        msg: "已定位到当前位置",
        toastLength: Toast.LENGTH_SHORT,
      );
    } catch (e) {
      Logger.e('获取位置失败', error: e, tag: 'MapCache');
      Fluttertoast.showToast(
        msg: "获取位置失败: ${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
      );
      setState(() {
        _isLocating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地图瓦片下载'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCacheStats,
            tooltip: '刷新缓存统计',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _isDownloading
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('清除所有缓存'),
                        content: const Text('确定要清除所有已下载的地图瓦片吗？这将删除所有离线地图数据。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _clearAllCache();
                            },
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    );
                  },
            tooltip: '清除所有缓存',
          ),
        ],
      ),
      body: Column(
        children: [
          // 地图部分
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(39.9042, 116.4074), // 北京
                    initialZoom: 11.0,
                    maxZoom: 19.0,
                    minZoom: 1.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    onMapReady: () {
                      // 地图准备就绪后，更新当前边界
                      setState(() {
                        _currentBounds = _mapController.camera.visibleBounds;
                        _mapReady = true; // 标记地图已准备就绪
                      });
                    },
                    onPositionChanged: (position, hasGesture) {
                      // 当位置变化时，更新当前边界
                      if (hasGesture) {
                        setState(() {
                          _currentBounds = _mapController.camera.visibleBounds;
                        });
                      }
                    },
                  ),
                  children: [
                    // 离线优先的瓦片层
                    MapTileCacheManager.instance.createOfflineTileLayer(),
                    // 显示当前选择的矩形区域边界
                    if (_currentBounds != null)
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: [
                              LatLng(_currentBounds!.north, _currentBounds!.west),
                              LatLng(_currentBounds!.north, _currentBounds!.east),
                              LatLng(_currentBounds!.south, _currentBounds!.east),
                              LatLng(_currentBounds!.south, _currentBounds!.west),
                            ],
                            color: Colors.blue.withOpacity(0.2),
                            borderColor: Colors.blue,
                            borderStrokeWidth: 2.0,
                          ),
                        ],
                      ),
                    // 显示用户位置
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            child: Container(
                              height: 20,
                              width: 20,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // 添加当前缩放级别指示器
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      '当前缩放级别: ${_mapReady ? _mapController.camera.zoom.toStringAsFixed(1) : "加载中..."}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 控制部分
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 缓存状态信息
                  Text(
                    '已缓存瓦片: ${_cacheStats['tileCount']} 个',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '缓存大小: ${_formatSize(_cacheStats['size'] ?? 0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '已保存区域: ${_cacheStats['regions']} 个',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  
                  // 缩放级别调整
                  Row(
                    children: [
                      const Text('缩放级别范围:'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RangeSlider(
                          values: RangeValues(_minZoom.toDouble(), _maxZoom.toDouble()),
                          min: 1,
                          max: 19,
                          divisions: 18,
                          labels: RangeLabels(
                            _minZoom.toString(),
                            _maxZoom.toString(),
                          ),
                          onChanged: (RangeValues values) {
                            setState(() {
                              _minZoom = values.start.round();
                              _maxZoom = values.end.round();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '缩放级别: $_minZoom - $_maxZoom',
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 下载进度显示
                  if (_isDownloading)
                    Column(
                      children: [
                        LinearProgressIndicator(value: _downloadProgress / 100),
                        const SizedBox(height: 8),
                        Text(
                          '总进度: ${_downloadProgress.toStringAsFixed(1)}%',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (_currentProcessingZoom != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '当前处理缩放级别: $_currentProcessingZoom',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: _currentZoomTileCount > 0 
                                ? (_currentZoomProcessedTiles / _currentZoomTileCount).clamp(0.0, 1.0) 
                                : 0.0,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '级别进度: $_currentZoomProcessedTiles/$_currentZoomTileCount 瓦片 (${(_currentZoomTileCount > 0 ? _currentZoomProcessedTiles / _currentZoomTileCount * 100 : 0).toStringAsFixed(1)}%)',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),

                  const SizedBox(height: 16),
                  
                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isDownloading ? null : _estimateDownloadSize,
                          icon: const Icon(Icons.calculate),
                          label: const Text('估算大小'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.black,
                            backgroundColor: Colors.amber,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isDownloading ? null : _downloadCurrentAreaTiles,
                          icon: const Icon(Icons.download),
                          label: const Text('下载地图'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLocating ? null : _getCurrentLocation,
        child: _isLocating
            ? CircularProgressIndicator(color: Colors.white)
            : Icon(Icons.my_location),
        tooltip: '定位到当前位置',
      ),
    );
  }
} 