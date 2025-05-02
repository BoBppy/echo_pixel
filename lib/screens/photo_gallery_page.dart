import 'package:echo_pixel/screens/image_viewer_page.dart';
import 'package:echo_pixel/screens/video_player_page.dart';
import 'package:echo_pixel/services/media_index_service.dart';
import 'package:echo_pixel/services/media_scanner.dart';
import 'package:echo_pixel/widgets/lazy_loading_image_thumbnail.dart';
import 'package:echo_pixel/widgets/lazy_loading_video_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class PhotoGalleryPage extends StatefulWidget {
  const PhotoGalleryPage({super.key});

  @override
  State<StatefulWidget> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('相册'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '时间线'),
            Tab(text: '相册'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimelineView(),
          _buildAlbumsView(),
        ],
      ),
    );
  }
  
  Widget _buildTimelineView() {
    final mediaIndexService = context.watch<MediaIndexService>();
    final indices = mediaIndexService.indices;
    final indicesSorted = indices.entries.toList();
    indicesSorted.sort((a, b) {
      final dateA = DateFormat("yyyy-MM-dd").parse(a.key);
      final dateB = DateFormat("yyyy-MM-dd").parse(b.key);
      return dateB.compareTo(dateA);
    });
    final mediaFiles = mediaIndexService.mediaFiles;
    final List<Widget> items = indicesSorted.map((entry) {
      final assets = entry.value.map((hash) => mediaFiles[hash]!).toList();
      return _buildPhotoItem(entry.key, assets);
    }).toList();
    
    return ListView.builder(
        itemCount: items.length,
        itemBuilder: (_, index) {
          return items[index];
      }
    );
  }
  
  Widget _buildAlbumsView() {
    final mediaIndexService = context.watch<MediaIndexService>();
    final albums = mediaIndexService.localAlbums;
    
    if (albums.isEmpty) {
      return const Center(
        child: Text('没有找到相册'),
      );
    }
    
    final albumEntries = albums.entries.toList();
    
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
      ),
      itemCount: albumEntries.length,
      itemBuilder: (context, index) {
        final album = albumEntries[index];
        final albumName = album.key;
        final assets = album.value;
        
        return _buildAlbumItem(albumName, assets);
      },
    );
  }
  
  Widget _buildAlbumItem(String albumName, List<MediaAsset> assets) {
    // 使用第一张图片作为封面
    final coverAsset = assets.isNotEmpty ? assets.first : null;
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailPage(
              albumName: albumName,
              assets: assets,
            ),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: coverAsset != null
                ? coverAsset.type == MediaAssetType.image
                  ? LazyLoadingImageThumbnail(
                      imagePath: coverAsset.file.path,
                      fit: BoxFit.cover,
                    )
                  : LazyLoadingVideoThumbnail(
                      videoPath: coverAsset.file.path,
                      fit: BoxFit.cover,
                    )
                : Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.folder, size: 50),
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${assets.length} 个项目',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoItem(String dateTimeString, List<MediaAsset> assets) {
    final dateTime = DateFormat("yyyy-MM-dd").parse(dateTimeString);
    final currentDateTime = DateTime.now();
    final isThisYear = dateTime.year == currentDateTime.year;
    final isToday = isThisYear &&
        dateTime.month == currentDateTime.month &&
        dateTime.day == currentDateTime.day;
    final isYesterday = isThisYear &&
        dateTime.month == currentDateTime.month &&
        dateTime.day == currentDateTime.day - 1;
    final date = Padding(
      padding: const EdgeInsets.all(10.0),
      child: Text(
        isToday
            ? "今天"
            : isYesterday
                ? "昨天"
                : isThisYear
                    ? DateFormat("MM月dd日").format(dateTime)
                    : DateFormat("yyyy年MM月dd日").format(dateTime),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    final waterfall = WaterfallFlow.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: assets.length,
        gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 5.0,
          mainAxisSpacing: 5.0,
        ),
        itemBuilder: (context, index) {
          final asset = assets[index];
          return _buildMediaItem(context, asset, assets, index);
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      date,
      waterfall,
    ]);
  }
  
  Widget _buildMediaItem(BuildContext context, MediaAsset asset, List<MediaAsset> allAssets, int index) {
    return switch (asset.type) {
      MediaAssetType.image => InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerPage(
                  mediaFile: asset,
                  mediaFiles: allAssets,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: LazyLoadingImageThumbnail(imagePath: asset.file.path),
        ),
      MediaAssetType.video => InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerPage(
                  mediaFile: asset,
                ),
              ),
            );
          },
          child: LazyLoadingVideoThumbnail(videoPath: asset.file.path),
        ),
    };
  }
}

class AlbumDetailPage extends StatelessWidget {
  final String albumName;
  final List<MediaAsset> assets;

  const AlbumDetailPage({
    super.key,
    required this.albumName,
    required this.assets,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(albumName),
      ),
      body: WaterfallFlow.builder(
        padding: const EdgeInsets.all(5.0),
        itemCount: assets.length,
        gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 5.0,
          mainAxisSpacing: 5.0,
        ),
        itemBuilder: (context, index) {
          final asset = assets[index];
          return switch (asset.type) {
            MediaAssetType.image => InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerPage(
                        mediaFile: asset,
                        mediaFiles: assets,
                        initialIndex: index,
                      ),
                    ),
                  );
                },
                child: LazyLoadingImageThumbnail(imagePath: asset.file.path),
              ),
            MediaAssetType.video => InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerPage(
                        mediaFile: asset,
                      ),
                    ),
                  );
                },
                child: LazyLoadingVideoThumbnail(videoPath: asset.file.path),
              ),
          };
        },
      ),
    );
  }
}
