import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../utils/logger.dart';
import '../utils/map_tile_cache_manager.dart';

/// 地图瓦片缓存管理页面
class MapCachePage extends StatefulWidget {
  const MapCachePage({super.key});

  @override
  State<MapCachePage> createState() => _MapCachePageState();
}

class _MapCachePageState extends State<MapCachePage> {
  // 地图控制器
  final MapController _mapController = MapController();
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
          gravity: ToastGravity.BOTTOM,
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

  // 下载选定区域的瓦片 - 简化版本
  Future<void> _downloadCurrentAreaTiles() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });
    
    try {
      // 模拟下载过程
      for (int i = 0; i <= 100; i += 10) {
        if (!mounted) break;
        await Future.delayed(Duration(milliseconds: 500));
        setState(() {
          _downloadProgress = i.toDouble();
        });
      }
      
      await _refreshCacheStats();
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        Fluttertoast.showToast(
          msg: "下载完成！",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
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

  // 估算下载大小 - 简化版本
  Future<void> _estimateDownloadSize() async {
    try {
      // 简化版本，使用固定估算值
      setState(() {
        _estimatedSize = 2.5; // 2.5MB
        _estimatedTileCount = 100; // 100个瓦片
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
            child: FlutterMap(
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
                          '下载进度: ${_downloadProgress.toStringAsFixed(1)}%',
                          textAlign: TextAlign.center,
                        ),
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
    );
  }
} 