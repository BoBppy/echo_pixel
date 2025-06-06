import 'dart:io';
import 'package:flutter/material.dart';
import '../services/thumbnail_service.dart';

/// 懒加载视频缩略图组件 - 使用ThumbnailService生成缩略图
class LazyLoadingVideoThumbnail extends StatefulWidget {
  final String videoPath;
  final BoxFit fit;

  const LazyLoadingVideoThumbnail({
    required this.videoPath,
    this.fit = BoxFit.cover,
    super.key,
  });

  @override
  State<LazyLoadingVideoThumbnail> createState() =>
      _LazyLoadingVideoThumbnailState();
}

class _LazyLoadingVideoThumbnailState extends State<LazyLoadingVideoThumbnail> {
  // 使用缩略图服务
  final ThumbnailService _thumbnailService = ThumbnailService();

  String? _thumbnailPath;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(LazyLoadingVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果视频路径发生变化，重新加载缩略图
    if (oldWidget.videoPath != widget.videoPath) {
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 使用缩略图服务获取视频缩略图路径
      final thumbnailPath = await _thumbnailService.getVideoThumbnail(
        widget.videoPath,
      );

      if (!mounted) return;

      setState(() {
        _thumbnailPath = thumbnailPath;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('生成视频缩略图错误: ${widget.videoPath} - $e');
      if (!mounted) return;

      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      // 显示加载占位符
      return Container(
        color: isDark ? Colors.blue[300] : Colors.blue[100],
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_hasError || _thumbnailPath == null) {
      // 显示错误占位符
      return Container(
        color: isDark ? Colors.red[300] : Colors.red[100],
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white60, size: 32),
        ),
      );
    }

    // 显示缩略图
    return Image.file(
      File(_thumbnailPath!),
      fit: widget.fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: isDark ? Colors.blue[300] : Colors.blue[100],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white60),
          ),
        );
      },
    );
  }
}
