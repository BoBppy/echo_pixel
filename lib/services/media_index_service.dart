import 'dart:async';

import 'package:echo_pixel/main.dart';
import 'package:echo_pixel/services/cloud_media_scanner.dart';
import 'package:echo_pixel/services/desktop_media_scanner.dart';
import 'package:echo_pixel/services/media_scanner.dart';
import 'package:echo_pixel/services/mobile_media_scanner.dart';
import 'package:flutter/foundation.dart';

class MediaIndexService extends ChangeNotifier {
  late MediaScanner _localScanner;
  late MediaScanner _cloudScanner;

  var _isScanning = false;

  MediaIndexService._();

  static Future<MediaIndexService> build() async {
    final service = MediaIndexService._();
    await service._initialize();
    return service;
  }

  Future<void> _initialize() async {
    if (isDesktopPlatform()) {
      _localScanner = await DesktopMediaScanner.build();
    } else {
      _localScanner = await MobileMediaScanner.build();
    }

    _cloudScanner = await CloudMediaScanner.build();

    // 如果没有资源就先触发一次扫描
    if (localIndices.isEmpty) {
      scan();
    }

    // 定时扫描资源
    Timer.periodic(Duration(seconds: 30), (timer) async {
      await scan();
    });

    notifyListeners();
  }

  /// 触发资源扫描
  Future<void> scan() async {
    if (_isScanning) return;
    final count = mediaFiles.length;
    _isScanning = true;
    await _localScanner.scan();
    await _cloudScanner.scan();
    _isScanning = false;
    final newCount = mediaFiles.length;
    debugPrint('扫描结束，新资源数量: $newCount，旧资源数量: $count');
    notifyListeners();
  }

  /// 所有索引(云端+本地)
  Map<String, List<String>> get indices {
    final Map<String, List<String>> combined = {};
    for (var entry in _localScanner.indices.entries) {
      combined[entry.key] = [...entry.value];
    }
    for (var entry in _cloudScanner.indices.entries) {
      combined.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }
    return combined;
  }

  /// 所有资源(云端+本地)
  Map<String, MediaAsset> get mediaFiles {
    final Map<String, MediaAsset> combined = {};
    for (var entry in _localScanner.mediaFiles.entries) {
      combined[entry.key] = entry.value;
    }
    for (var entry in _cloudScanner.mediaFiles.entries) {
      combined.putIfAbsent(entry.key, () => entry.value);
    }
    return combined;
  }

  /// 本地索引
  Map<String, List<String>> get localIndices => _localScanner.indices;

  /// 本地资源
  Map<String, MediaAsset> get localMediaFiles => _localScanner.mediaFiles;

  /// 云端索引
  Map<String, List<String>> get cloudIndices => _cloudScanner.indices;

  /// 云端资源
  Map<String, MediaAsset> get cloudMediaFiles => _cloudScanner.mediaFiles;

  /// 按相册/文件夹分组的本地资源
  Map<String, List<MediaAsset>> get localAlbums {
    final Map<String, List<MediaAsset>> albums = {};
    
    for (final asset in localMediaFiles.values) {
      if (asset.sourceAlbumOrFolder == null) continue;
      
      final albumName = asset.sourceAlbumOrFolder!;
      if (!albums.containsKey(albumName)) {
        albums[albumName] = [];
      }
      
      albums[albumName]!.add(asset);
    }
    
    return albums;
  }
}
