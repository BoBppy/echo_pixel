import 'package:echo_pixel/services/media_scanner.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart';

class VideoPlayerPage extends StatefulWidget {
  final MediaAsset mediaFile;

  const VideoPlayerPage({
    required this.mediaFile,
    super.key,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  // 创建一个播放器实例
  late final Player _player;
  // 创建视频控制器
  late final VideoController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // 创建播放器实例
      _player = Player();
      // 创建视频控制器
      _controller = VideoController(_player);

      // 打开视频文件
      final videoFile = widget.mediaFile.file;
      if (!videoFile.existsSync()) {
        throw Exception('视频文件不存在');
      }

      await _player.open(Media(widget.mediaFile.file.path));

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('初始化视频播放器失败: $e, $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(basename(widget.mediaFile.file.path)),
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
      ),
      body: !_isInitialized ? _buildLoadingView() : _buildVideoPlayer(),
    );
  }

  // 构建加载视图
  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            '正在加载视频...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // 构建视频播放器
  Widget _buildVideoPlayer() {
    // 媒体信息
    final mediaInfo = widget.mediaFile;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 视频播放器
          Expanded(
            child: Video(
              controller: _controller,
              controls: MaterialDesktopVideoControls,
              wakelock: true,
            ),
          ),

          // 视频信息面板
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.black.withValues(alpha: 0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  basename(mediaInfo.file.path),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '文件大小: ${_formatSize(mediaInfo.file.lengthSync())}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '修改时间: ${_formatDate(mediaInfo.file.statSync().modified)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 格式化日期
  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日 ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  // 格式化文件大小
  String _formatSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)}${suffixes[i]}';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
