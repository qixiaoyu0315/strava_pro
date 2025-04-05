import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../utils/map_tile_cache_manager.dart';

class RegionPreviewPage extends StatefulWidget {
  final Map<String, dynamic> regionInfo;
  final String regionName;

  const RegionPreviewPage({
    super.key,
    required this.regionInfo,
    required this.regionName,
  });

  @override
  State<RegionPreviewPage> createState() => _RegionPreviewPageState();
}

class _RegionPreviewPageState extends State<RegionPreviewPage> {
  final MapController _mapController = MapController();
  late LatLngBounds _bounds;

  @override
  void initState() {
    super.initState();
    _initializeBounds();
  }

  void _initializeBounds() {
    final bounds = widget.regionInfo['bounds'] as Map<String, dynamic>;
    _bounds = LatLngBounds(
      LatLng(bounds['south'] as double, bounds['west'] as double),
      LatLng(bounds['north'] as double, bounds['east'] as double),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('区域预览: ${widget.regionName}'),
      ),
      body: Column(
        children: [
          // 地图显示
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _bounds.center,
                initialZoom: 11.0,
                maxZoom: 19.0,
                minZoom: 1.0,
                onMapReady: () {
                  // 地图加载完成后，自动缩放到区域范围
                  _mapController.fitCamera(
                    CameraFit.bounds(
                      bounds: _bounds,
                      padding: const EdgeInsets.all(32.0),
                    ),
                  );
                },
              ),
              children: [
                // 使用缓存的瓦片图层
                MapTileCacheManager.instance.createOfflineTileLayer(),
                // 显示区域边界
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: [
                        LatLng(_bounds.north, _bounds.west),
                        LatLng(_bounds.north, _bounds.east),
                        LatLng(_bounds.south, _bounds.east),
                        LatLng(_bounds.south, _bounds.west),
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
          // 区域信息
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '区域信息',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                _buildInfoRow('缩放级别', '${widget.regionInfo['minZoom']}-${widget.regionInfo['maxZoom']}'),
                _buildInfoRow('瓦片数量', '${widget.regionInfo['tileCount']} 个'),
                _buildInfoRow('缓存大小', _formatSize(widget.regionInfo['size'] as int)),
                _buildInfoRow('下载时间', _formatDateTime(widget.regionInfo['date'] as String)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr).toLocal();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeStr;
    }
  }
} 