import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../utils/map_tile_cache_manager.dart';
import '../utils/logger.dart';

/// 区域管理页面
class RegionManagePage extends StatefulWidget {
  const RegionManagePage({super.key});

  @override
  State<RegionManagePage> createState() => _RegionManagePageState();
}

class _RegionManagePageState extends State<RegionManagePage> {
  bool _isLoading = true;
  Map<String, dynamic> _regions = {};
  Map<String, dynamic> _cacheStats = {
    'size': 0,
    'tileCount': 0,
    'regions': 0,
  };
  
  @override
  void initState() {
    super.initState();
    _loadRegions();
  }
  
  // 加载已保存的区域
  Future<void> _loadRegions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final regions = await MapTileCacheManager.instance.getSavedRegions();
      final stats = await MapTileCacheManager.instance.getCacheStats();
      
      setState(() {
        _regions = regions;
        _cacheStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      Logger.e('加载区域信息失败', error: e, tag: 'RegionManage');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        Fluttertoast.showToast(
          msg: "加载区域信息失败：${e.toString()}",
          toastLength: Toast.LENGTH_LONG,
        );
      }
    }
  }
  
  // 删除单个区域
  Future<void> _deleteRegion(String regionId, Map<String, dynamic> regionInfo) async {
    try {
      final result = await MapTileCacheManager.instance.deleteRegion(regionId);
      
      if (result) {
        // 刷新加载区域和统计信息
        await _loadRegions();
        
        Fluttertoast.showToast(
          msg: "区域已删除",
          toastLength: Toast.LENGTH_SHORT,
        );
      } else {
        throw Exception("删除失败");
      }
    } catch (e) {
      Logger.e('删除区域失败', error: e, tag: 'RegionManage');
      Fluttertoast.showToast(
        msg: "删除区域失败：${e.toString()}",
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }
  
  // 清除所有缓存
  Future<void> _clearAllCache() async {
    try {
      // 使用缓存管理器的方法清除所有区域
      final result = await MapTileCacheManager.instance.clearAllRegions();
      
      if (result) {
        // 刷新加载区域和统计信息
        await _loadRegions();
        
        if (mounted) {
          Fluttertoast.showToast(
            msg: "所有缓存已清除",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
          );
        }
      } else {
        throw Exception("清除失败");
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
  
  // 格式化缓存大小
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  
  // 格式化日期时间
  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }
  
  // 构建缓存统计卡片
  Widget _buildCacheStatsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storage,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '缓存统计',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${_cacheStats['tileCount']}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      '瓦片数量',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      _formatSize(_cacheStats['size'] ?? 0),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    Text(
                      '缓存大小',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${_cacheStats['regions']}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      '区域数量',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('已缓存区域管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRegions,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _regions.isEmpty 
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 缓存统计卡片
                _buildCacheStatsCard(),
                
                // 区域列表
                Expanded(
                  child: _regions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.map_outlined,
                                size: 60,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '暂无缓存区域',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '返回地图页面下载区域以使用离线地图',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('返回地图页面'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _regions.length,
                          itemBuilder: (context, index) {
                            final regionId = _regions.keys.elementAt(index);
                            final regionInfo = _regions[regionId] as Map<String, dynamic>;
                            final dateStr = _formatDateTime(regionInfo['date'] as String? ?? '');
                            final tileCount = regionInfo['tileCount'] as int? ?? 0;
                            final size = regionInfo['size'] as int? ?? 0;
                            final minZoom = regionInfo['minZoom'] as int? ?? 0;
                            final maxZoom = regionInfo['maxZoom'] as int? ?? 0;
                            
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            regionInfo['name'] as String? ?? '未命名区域',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          color: Colors.red,
                                          tooltip: '删除此区域',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('删除区域'),
                                                content: const Text('确定要删除此区域的缓存吗？此操作不可恢复。'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.of(context).pop(),
                                                    child: const Text('取消'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.of(context).pop();
                                                      _deleteRegion(regionId, regionInfo);
                                                    },
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.red,
                                                    ),
                                                    child: const Text('删除'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '下载日期: $dateStr',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '瓦片数量: $tileCount',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '占用空间: ${_formatSize(size)}',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '缩放级别: $minZoom-$maxZoom',
                                                style: TextStyle(
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.map,
                                            color: Colors.blue.shade700,
                                            size: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
} 