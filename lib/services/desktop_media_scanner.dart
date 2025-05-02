import 'dart:convert';
import 'dart:io';

import 'package:echo_pixel/services/media_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

class DesktopMediaScanner extends MediaScanner {
  Map<String, List<String>> _indices = {};
  Map<String, MediaAsset> _mediaFiles = {};

  bool _isScanning = false;
  double _scanProgress = 0.0;

  late Directory _cacheDir;

  @override
  Map<String, List<String>> get indices => _indices;

  @override
  Map<String, MediaAsset> get mediaFiles => _mediaFiles;

  /// 禁止外部构造
  DesktopMediaScanner._();

  static build() async {
    final scanner = DesktopMediaScanner._();
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
    await mediaFilesCache.writeAsString(json.encode(
        _mediaFiles.map((hash, asset) => MapEntry(hash, asset.toJson()))));
  }

  @override
  Future<void> scan() async {
    if (_isScanning) {
      throw StateError('已在扫描中');
    }

    // 扫描只能同时运行一个
    _isScanning = true;
    // 重设扫描进度
    _scanProgress = 0.0;

    try {
      // 获取要扫描的文件夹
      final prefs = await SharedPreferences.getInstance();
      final dirsToScan = prefs.getStringList('scan_folders');

      if (dirsToScan == null || dirsToScan.isEmpty) {
        return;
      }

      List<String> dirsToRemove = [];

      Map<String, List<String>> indices = {};
      Map<String, MediaAsset> mediaFiles = {};

      for (final dir in dirsToScan) {
        final dirToScan = Directory(dir);
        if (!await dirToScan.exists()) {
          // 如果目录不存在，标记需要删除并跳过
          dirsToRemove.add(dir);
          continue;
        }

        await for (final entity in dirToScan.list(recursive: true)) {
          if (entity is File) {
            if (!isAlbumAsset(entity.path)) continue;
            final mine = lookupMimeType(entity.path)!;
            final hash = await assetHash(entity);
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
                
            // 提取相对路径并获取文件夹名称
            final relativePath = p.relative(entity.path, from: dir);
            final dirPath = p.dirname(relativePath);
            
            // 处理根目录情况
            final sourceAlbumOrFolder = dirPath == '.' ? p.basename(dir) : dirPath;
            
            mediaFiles[hash] = MediaAsset(entity, type, sourceAlbumOrFolder: sourceAlbumOrFolder);
          }
        }
      }

      // 在扫描设置中删除不存在的目录
      for (final dir in dirsToRemove) {
        dirsToScan.remove(dir);
      }
      prefs.setStringList('scan_folders', dirsToScan);

      _indices = indices;
      _mediaFiles = mediaFiles;

      await _saveToCache();
    } catch (e, stackTrace) {
      debugPrint('桌面端扫描失败: $e, $stackTrace');
    } finally {
      // 因为没有预先的数量，没法实时计算进度，直接设为 1.0
      _scanProgress = 1.0;
      _isScanning = false;
    }
  }

  @override
  double get scanProgress => _scanProgress;
}
