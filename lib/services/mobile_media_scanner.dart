import 'dart:convert';
import 'dart:io';

import 'package:echo_pixel/services/media_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path/path.dart' as p;

class MobileMediaScanner extends MediaScanner {
  bool _isScanning = false;
  late Directory _cacheDir;
  double _scanProgress = 0.0;
  Map<String, List<String>> _indices = {};
  Map<String, MediaAsset> _mediaFiles = {};

  /// 禁止外部构造
  MobileMediaScanner._();

  static Future<MobileMediaScanner> build() async {
    final scanner = MobileMediaScanner._();
    await scanner.initialize();
    return scanner;
  }

  Future<void> initialize() async {
    _cacheDir = await indexCacheDirectory;
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
    await _loadFromCache();
  }

  @override
  double get scanProgress => _scanProgress;

  @override
  Map<String, List<String>> get indices => _indices;

  @override
  Map<String, MediaAsset> get mediaFiles => _mediaFiles;

  String get indiceCachePath {
    return '${_cacheDir.path}${Platform.pathSeparator}indices.json';
  }

  String get mediaFilesCachePath {
    return '${_cacheDir.path}${Platform.pathSeparator}media_files.json';
  }

  /// 从缓存加载
  Future<void> _loadFromCache() async {
    final indicesCache = File(indiceCachePath);
    if (await indicesCache.exists()) {
      final cache = await indicesCache.readAsString();
      final raw = json.decode(cache) as Map<String, dynamic>;
      _indices = raw.map<String, List<String>>(
        (key, value) => MapEntry(
          key,
          // 把 List<dynamic> 转成 List<String>
          List<String>.from((value as List<dynamic>)),
        ),
      );
    }

    final mediaFilesCache = File(mediaFilesCachePath);
    if (await mediaFilesCache.exists()) {
      final cache = await mediaFilesCache.readAsString();
      _mediaFiles = Map<String, Map<String, dynamic>>.from(json.decode(cache))
          .map((hash, asset) => MapEntry(hash, MediaAsset.fromJson(asset)));
    }
  }

  /// 保存到缓存
  Future<void> _saveToCache() async {
    final indicesCache = File(indiceCachePath);
    await indicesCache.writeAsString(json.encode(_indices));

    final mediaFilesCache = File(mediaFilesCachePath);
    await mediaFilesCache.writeAsString(
        json.encode(_mediaFiles.map((k, v) => MapEntry(k, v.toJson()))));
  }

  @override
  Future<void> scan() async {
    if (_isScanning) {
      throw StateError('已在扫描中');
    }

    // 扫描只能同时运行一个
    _isScanning = true;

    try {
      // 重设扫描进度
      _scanProgress = 0.0;

      // 因为有权限引导页，这里不需要检查权限
      // 检查权限
      // final permissionStatus = await PhotoManager.requestPermissionExtend();
      // if (!permissionStatus.isAuth) {
      //   throw Exception('相册权限未授权');
      // }

      // 获取所有媒体资源路径
      // 仅获取'全部'相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        onlyAll: true,
        hasAll: true,
      );

      final album = albums.first; // '全部'相册
      final assetsCount = await album.assetCountAsync;
      final Map<String, List<String>> indices = {};
      final Map<String, MediaAsset> mediaFiles = {};

      const int batchSize = 16;
      final int pageCount = (assetsCount / batchSize).ceil();

      var scannedAssets = 0;

      for (int page = 0; page < pageCount; page += 1) {
        final assets =
            await album.getAssetListPaged(page: page, size: batchSize);
        for (final entity in assets) {
          final date = entity.createDateTime;
          final dateString = '${date.year}-${date.month}-${date.day}';
          final file = await entity.file;
          if (file == null) {
            continue; // 跳过没有文件的资源(为什么会有?)
          }
          final hash = await assetHash(file);

          // 如果还没有日期分类，添加
          if (!indices.containsKey(dateString)) {
            indices[dateString] = [];
          }

          final mine = lookupMimeType(file.path);
          if (mine == null) {
            continue;
          }
          final type = mine.startsWith('image')
              ? MediaAssetType.image
              : MediaAssetType.video;
              
          // 提取文件夹名称
          final sourceAlbumOrFolder = p.basename(p.dirname(file.path));
          
          indices[dateString]!.add(hash);
          mediaFiles[hash] = MediaAsset(file, type, sourceAlbumOrFolder: sourceAlbumOrFolder);
          scannedAssets += 1;
          _scanProgress = scannedAssets / assetsCount;
        }
      }

      _indices = indices;
      _mediaFiles = mediaFiles;

      await _saveToCache();
    } catch (e, stackTrace) {
      debugPrint('移动端扫描失败: $e, $stackTrace');
    } finally {
      _isScanning = false;
    }
  }
}
