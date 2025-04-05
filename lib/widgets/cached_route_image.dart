import 'package:flutter/material.dart';
import '../utils/route_image_cache_manager.dart';
import 'dart:typed_data';

/// 缓存路线图片组件
/// 提供高效的路线地图图片加载和缓存
class CachedRouteImage extends StatefulWidget {
  final String imageUrl;
  final String? darkImageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext, String)? errorBuilder;
  final Widget? placeholder;
  
  /// 创建缓存路线图片组件
  /// [imageUrl] 路线图片URL
  /// [darkImageUrl] 暗黑模式下的路线图片URL
  /// [fit] 图片适配方式
  /// [width] 图片宽度
  /// [height] 图片高度
  /// [errorBuilder] 错误构建器
  /// [placeholder] 加载占位组件
  const CachedRouteImage({
    super.key,
    required this.imageUrl,
    this.darkImageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
    this.placeholder,
  });

  @override
  State<CachedRouteImage> createState() => _CachedRouteImageState();
}

class _CachedRouteImageState extends State<CachedRouteImage> with AutomaticKeepAliveClientMixin {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;
  Object? _error;
  String? _currentUrl;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    _isLoading = true;
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeImage();
  }

  void _initializeImage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final newUrl = isDarkMode && widget.darkImageUrl != null 
        ? widget.darkImageUrl! 
        : widget.imageUrl;
        
    if (_currentUrl != newUrl) {
      _currentUrl = newUrl;
      _loadImage();
    }
  }
  
  @override
  void didUpdateWidget(CachedRouteImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeImage();
  }

  Future<void> _loadImage() async {
    if (!mounted || _currentUrl == null) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
      _error = null;
    });
    
    try {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      
      // 通过缓存管理器获取图片
      final bytes = await RouteImageCacheManager.instance.getImageFromUrl(
        _currentUrl!, 
        isDarkMode: isDarkMode,
      );
      
      if (!mounted) return;
      
      setState(() {
        _imageBytes = bytes;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _hasError = true;
        _error = e;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_isLoading) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.placeholder ?? const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (_hasError) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorBuilder?.call(context, _error.toString()) ?? 
          Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
            ),
          ),
      );
    }
    
    if (_imageBytes == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorBuilder?.call(context, "No image data") ?? 
          Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
            ),
          ),
      );
    }
    
    return Image.memory(
      _imageBytes!,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      filterQuality: FilterQuality.high,
      cacheWidth: widget.width?.toInt(),
      cacheHeight: widget.height?.toInt(),
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null) {
          return child;
        }
        return widget.placeholder ?? const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }
} 