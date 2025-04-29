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

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
  @override
  Widget build(BuildContext context) {
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
        });
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
        });
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      date,
      waterfall,
    ]);
  }
}
