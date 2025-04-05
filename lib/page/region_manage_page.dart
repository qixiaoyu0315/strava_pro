import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../utils/map_tile_cache_manager.dart';
import '../utils/logger.dart';
import './region_preview_page.dart';

/// 区域管理页面
class RegionManagePage extends StatefulWidget {
  const RegionManagePage({super.key});

  @override
  State<RegionManagePage> createState() => _RegionManagePageState();
}

class _RegionManagePageState extends State<RegionManagePage> {
  bool _isLoading = true;
  Map<String, dynamic> _regions = {};
  
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
      
      if (!mounted) return;
      
      setState(() {
        _regions = regions;
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
        // 刷新加载区域
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
        // 刷新加载区域
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
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }

  // 显示删除确认对话框
  void _showDeleteConfirmation(
    BuildContext context,
    String regionId,
    Map<String, dynamic> regionInfo,
  ) {
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
          : _regions.isEmpty
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
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        title: Text(
                          regionInfo['name'] ?? '未命名区域',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('下载时间: ${_formatDateTime(regionInfo['date'] as String)}'),
                            Text('瓦片数量: ${regionInfo['tileCount']} 个'),
                            Text('缓存大小: ${_formatSize(regionInfo['size'] as int)}'),
                            Text('缩放级别: ${regionInfo['minZoom']}-${regionInfo['maxZoom']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 添加预览按钮
                            IconButton(
                              icon: const Icon(Icons.map),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RegionPreviewPage(
                                      regionInfo: regionInfo,
                                      regionName: regionInfo['name'] ?? '未命名区域',
                                    ),
                                  ),
                                );
                              },
                              tooltip: '预览区域',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _showDeleteConfirmation(
                                context,
                                regionId,
                                regionInfo,
                              ),
                              tooltip: '删除区域',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
} 