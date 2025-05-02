import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:exif/exif.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

enum MediaAssetType {
  /// 图片
  image,

  /// 视频
  video,
}

class MediaAsset {
  /// 文件
  final File file;

  /// 类型
  final MediaAssetType type;

  /// 来源相册或文件夹
  final String? sourceAlbumOrFolder;

  MediaAsset(this.file, this.type, {this.sourceAlbumOrFolder});

  /// 转JSON
  Map<String, dynamic> toJson() {
    return {
      'path': file.path,
      'type': type.index,
      'source_album_or_folder': sourceAlbumOrFolder,
    };
  }

  /// 从JSON转换
  static MediaAsset fromJson(Map<String, dynamic> json) {
    final path = json['path'] as String;
    final type = MediaAssetType.values[json['type'] as int];
    final sourceAlbumOrFolder = json['source_album_or_folder'] as String?;
    return MediaAsset(File(path), type, sourceAlbumOrFolder: sourceAlbumOrFolder);
  }
}

abstract class MediaScanner {
  /// 扫描进度
  double get scanProgress;

  /// 日期-媒体Hash索引
  /// 日期格式为 YYYY-MM-DD
  Map<String, List<String>> get indices;

  /// 媒体Hash-媒体文件索引
  Map<String, MediaAsset> get mediaFiles;

  /// 扫描操作
  Future<void> scan();

  bool get isEmpty => indices.isEmpty || mediaFiles.isEmpty;
}

/// 获取本地索引缓存目录
Future<Directory> get indexCacheDirectory async {
  final cacheDir = await getApplicationCacheDirectory();
  final indexDir = Directory('${cacheDir.path}${Platform.pathSeparator}index');
  return indexDir;
}

/// 获取云端索引缓存路径
Future<Directory> get cloudIndexCacheDirectory async {
  final cacheDir = await getApplicationSupportDirectory();
  final indexDir =
      Directory('${cacheDir.path}${Platform.pathSeparator}cloud_index');
  return indexDir;
}

Future<String> assetHash(File file,
    {int sampleSize = 4096, int threshold = 100 * 1024}) async {
  final length = await file.length();

  if (length <= threshold) {
    // 小文件：全量读取
    final full = await file.readAsBytes();
    return sha256.convert(full).toString();
  } else {
    // 大文件：采样开头、中间、结尾
    final raf = await file.open();
    try {
      await raf.setPosition(0);
      final startBytes = await raf.read(sampleSize);

      final middleOffset = (length ~/ 2) - (sampleSize ~/ 2);
      await raf.setPosition(middleOffset);
      final middleBytes = await raf.read(sampleSize);

      final endOffset = length - sampleSize;
      await raf.setPosition(endOffset);
      final endBytes = await raf.read(sampleSize);

      final builder = BytesBuilder();
      builder.add(startBytes);
      builder.add(middleBytes);
      builder.add(endBytes);
      final combined = builder.toBytes();

      return sha256.convert(combined).toString();
    } finally {
      await raf.close();
    }
  }
}

Future<DateTime> getDateTimeFromAsset(File asset, String mime) async {
  if (mime.startsWith('image/')) {
    final fileBytes = await asset.readAsBytes();
    final data = await readExifFromBytes(fileBytes);
    final dateTimeOrginal = data['DateTimeOriginal'];
    if (dateTimeOrginal == null) {
      return getDateTimeFromStat(asset);
    } else {
      final dateTimeString = dateTimeOrginal.printable;
      final dateTime = DateFormat('yyyy:MM:dd HH:mm:ss').parse(dateTimeString);
      return dateTime;
    }
  } else {
    return getDateTimeFromStat(asset);
  }
}

Future<DateTime> getDateTimeFromStat(File asset) async {
  final stat = await asset.stat();
  return stat.modified;
}

bool isAlbumAsset(String path) {
  final mime = lookupMimeType(path);
  if (mime == null) {
    return false;
  }
  return mime.startsWith('image/') || mime.startsWith('video/');
}
