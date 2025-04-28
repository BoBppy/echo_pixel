import 'dart:io';
import 'package:echo_pixel/services/media_scanner.dart';
import 'package:flutter/material.dart';
import '../widgets/gif_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

class ImageViewerPage extends StatefulWidget {
  final MediaAsset mediaFile;
  final List<MediaAsset>? mediaFiles; // 同一组中的所有媒体文件，用于左右滑动浏览
  final int initialIndex; // 初始显示的索引

  const ImageViewerPage({
    super.key,
    required this.mediaFile,
    this.mediaFiles,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isControlsVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    // 延迟自动隐藏控制栏
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isControlsVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
  }

  void _shareImage() {
    final MediaAsset currentFile = widget.mediaFiles != null
        ? widget.mediaFiles![_currentIndex]
        : widget.mediaFile;

    SharePlus.instance.share(ShareParams(
      files: [XFile(currentFile.file.path)],
      previewThumbnail: XFile(currentFile.file.path),
      text: 'Sharing ${path.basename(currentFile.file.path)}',
    ));
  }

  // 检查当前查看的文件是否为GIF
  bool _isGifFile(MediaAsset file) {
    return file.file.path.toLowerCase().endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    // 如果提供了媒体文件列表，使用Gallery模式
    final bool isGalleryMode =
        widget.mediaFiles != null && widget.mediaFiles!.isNotEmpty;
    final List<MediaAsset> files =
        isGalleryMode ? widget.mediaFiles! : [widget.mediaFile];

    // 检查当前文件是否为GIF
    final bool isCurrentGif = _isGifFile(files[_currentIndex]);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _isControlsVisible
          ? AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              title: Text(
                path.basename(files[_currentIndex].file.path),
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                // 如果是GIF，显示GIF标签
                if (isCurrentGif)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: _shareImage,
                  tooltip: '分享',
                ),
              ],
            )
          : null,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: _toggleControls,
        child: isGalleryMode
            ? PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (context, index) {
                  final MediaAsset asset = files[index];
                  final bool isGif = _isGifFile(asset);

                  // 根据文件类型选择不同的显示组件
                  if (isGif) {
                    return PhotoViewGalleryPageOptions.customChild(
                      child: Center(
                        child: GifPlayer(
                          filePath: asset.file.path,
                          fit: BoxFit.contain,
                          autoPlay: true,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      maxScale: PhotoViewComputedScale.covered * 2.0,
                    );
                  } else {
                    // 普通图片使用标准PhotoView
                    return PhotoViewGalleryPageOptions(
                      imageProvider: FileImage(File(asset.file.path)),
                      initialScale: PhotoViewComputedScale.contained,
                      minScale: PhotoViewComputedScale.contained * 0.8,
                      maxScale: PhotoViewComputedScale.covered * 2.0,
                    );
                  }
                },
                itemCount: files.length,
                loadingBuilder: (context, event) => Center(
                  child: SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      value: event == null
                          ? 0
                          : event.cumulativeBytesLoaded /
                              event.expectedTotalBytes!,
                    ),
                  ),
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
              )
            : _buildSingleImageView(files[0]), // 单图模式
      ),
      bottomNavigationBar: _isControlsVisible && isGalleryMode
          ? BottomAppBar(
              color: Colors.black.withValues(alpha: 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_currentIndex + 1} / ${files.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  // 构建单图查看模式
  Widget _buildSingleImageView(MediaAsset asset) {
    final bool isGif = _isGifFile(asset);

    if (isGif) {
      // GIF文件使用GifPlayer
      return Center(
        child: GifPlayer(
          filePath: asset.file.path,
          fit: BoxFit.contain,
          autoPlay: true,
          filterQuality: FilterQuality.high,
        ),
      );
    } else {
      // 普通图片使用PhotoView
      return PhotoView(
        imageProvider: FileImage(asset.file),
        initialScale: PhotoViewComputedScale.contained,
        minScale: PhotoViewComputedScale.contained * 0.8,
        maxScale: PhotoViewComputedScale.covered * 2.0,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      );
    }
  }
}
