import 'dart:convert';
import 'dart:io';

import 'package:echo_pixel/services/media_scanner.dart';
import 'package:echo_pixel/services/media_sync_service.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';

class CloudMediaScanner extends MediaScanner {
  Map<String, List<String>> _indices = {};
  Map<String, MediaAsset> _mediaFiles = {};

  late Directory _cacheDir;

  double _scanProgress = 0.0;
  bool _isScanning = false;

  /// 禁止外部构造
  CloudMediaScanner._();

  static Future<CloudMediaScanner> build() async {
    final scanner = CloudMediaScanner._();
    await scanner.initialize();
    return scanner;
  }

  Future<void> initialize() async {
    _cacheDir = await cloudIndexCacheDirectory;
    if (!await _cacheDir.exists()) {
      await _cacheDir.create(recursive: true);
    }
    await _loadFromCache();
  }

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
    await mediaFilesCache.writeAsString(json.encode(
        _mediaFiles.map((hash, asset) => MapEntry(hash, asset.toJson()))));
  }

  @override
  Map<String, List<String>> get indices => _indices;

  @override
  Map<String, MediaAsset> get mediaFiles => _mediaFiles;

  @override
  double get scanProgress => _scanProgress;

  @override
  Future<void> scan() async {
    if (_isScanning) {
      throw StateError('已在扫描中');
    }

    _isScanning = true;

    try {
      _scanProgress = 0.0;
      final mediaDir = await cloudMediaDirectory;

      Map<String, List<String>> indices = {};
      Map<String, MediaAsset> mediaFiles = {};

      await for (final entity in mediaDir.list(recursive: true)) {
        if (entity is File) {
          // 云端资源命名格式: {hash}_{name}

          final mine = lookupMimeType(entity.path)!;
          // 从文件名中提取hash
          final hash = entity.uri.pathSegments.last.split('_').first;
          final date = await getDateTimeFromAsset(entity, mine);
          final dateString = "${date.year}-${date.month}-${date.day}";

          // 如果日期分类还不存在，添加
          if (!indices.containsKey(dateString)) {
            indices[dateString] = [];
          }

          indices[dateString]!.add(hash);
          final type = mine.startsWith('image')
              ? MediaAssetType.image
              : MediaAssetType.video;
          mediaFiles[hash] = MediaAsset(entity, type);
        }
      }

      _indices = indices;
      _mediaFiles = mediaFiles;

      await _saveToCache();
    } catch (e, stackTrace) {
      debugPrint('扫描失败: $e, $stackTrace');
    } finally {
      _isScanning = false;
    }
  }
}
