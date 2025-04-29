import 'dart:io';

import 'package:echo_pixel/main.dart';
import 'package:echo_pixel/services/foreground_sync_service.dart';
import 'package:echo_pixel/services/media_index_service.dart';
import 'package:echo_pixel/services/media_scanner.dart';
import 'package:echo_pixel/services/webdav_service.dart';
import 'package:flutter/material.dart';
import 'package:p_limit/p_limit.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 资源对象
/// 资源对象文件命名格式: {hash}_{name}
class MediaObject {
  final String hash;
  final String name;

  MediaObject(this.hash, this.name);
  MediaObject.fromString(String str)
      : hash = str.split('_')[0],
        name = str.split('_')[1];

  @override
  String toString() {
    return '${hash}_$name';
  }
}

class _UploadMediaObject {
  final MediaObject object;
  final File file;

  _UploadMediaObject(this.object, this.file);

  @override
  String toString() {
    return object.toString();
  }
}

abstract class SyncStep {
  Icon get icon;
  Icon get activeIcon;
  String get title;
  Widget content(MediaSyncService syncService, MediaIndexService indexService,
      WebDavService webDavService);
  Future<void> task(int nextStepIndex, MediaSyncService syncService,
      MediaIndexService indexService);

  static List<SyncStep> allSteps = [
    WaitingStep(),
    InitWebDavDirectoryStep(),
    UpdateCloudObjectsStep(),
    SyncFromCloudStep(),
    SyncToCloudStep(),
    SyncCompletedStep(),
  ];
}

class WaitingStep implements SyncStep {
  @override
  Icon get icon => const Icon(Icons.play_arrow_outlined);

  @override
  Icon get activeIcon => const Icon(Icons.play_arrow_outlined);

  @override
  String get title => '开始同步';

  @override
  Widget content(MediaSyncService service, MediaIndexService indexService,
      WebDavService webDavService) {
    return Padding(
        padding: EdgeInsetsGeometry.all(5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('点击开始同步'),
            const SizedBox(height: 10),
            FilledButton(
                onPressed: webDavService.isConnected
                    ? () {
                        if (!isDesktopPlatform()) {
                          ForegroundSyncService.startForegroundTask(
                            desc: title,
                          );
                        }
                        final nextStep = service.currentStep + 1;
                        SyncStep.allSteps[nextStep]
                            .task(nextStep + 1, service, indexService);
                        service.currentStep += 1;
                      }
                    : null,
                child: const Icon(Icons.play_arrow_outlined)),
          ],
        ));
  }

  @override
  Future<void> task(int nextStepIndex, MediaSyncService syncService,
      MediaIndexService indexService) async {
    syncService.errorMessage = '';
  }
}

class InitWebDavDirectoryStep implements SyncStep {
  @override
  Icon get icon => const Icon(Icons.create_new_folder_outlined);

  @override
  Icon get activeIcon => const Icon(Icons.create_new_folder_outlined);

  @override
  String get title => '初始化WebDav目录';

  @override
  Widget content(MediaSyncService syncService, MediaIndexService indexService,
      WebDavService webDavService) {
    return const Text('正在初始化WebDav目录...');
  }

  @override
  Future<void> task(int nextStepIndex, MediaSyncService syncService,
      MediaIndexService indexService) async {
    ForegroundSyncService.updateNotification(
      desc: title,
    );
    await syncService.initWebDavDirectory();
    SyncStep.allSteps[nextStepIndex]
        .task(nextStepIndex + 1, syncService, indexService);
    syncService.currentStep += 1;
  }
}

class UpdateCloudObjectsStep implements SyncStep {
  @override
  Icon get icon => const Icon(Icons.cloud_sync_outlined);

  @override
  Icon get activeIcon => const Icon(Icons.cloud_sync_outlined);

  @override
  String get title => '更新云端资源列表';

  @override
  Widget content(MediaSyncService syncService, MediaIndexService indexService,
      WebDavService webDavService) {
    return const Text('正在列出云端资源...');
  }

  @override
  Future<void> task(int nextStepIndex, MediaSyncService syncService,
      MediaIndexService indexService) async {
    ForegroundSyncService.updateNotification(
      desc: title,
    );
    try {
      await syncService.updateCloudObjects();
    } catch (e) {
      syncService.errorMessage = '更新云端资源列表失败: $e';
      return;
    }
    SyncStep.allSteps[nextStepIndex]
        .task(nextStepIndex + 1, syncService, indexService);
    syncService.currentStep += 1;
  }
}

class SyncFromCloudStep implements SyncStep {
  @override
  Icon get icon => const Icon(Icons.cloud_download_outlined);

  @override
  Icon get activeIcon => const Icon(Icons.cloud_download_outlined);

  @override
  String get title => '从云端同步资源';

  @override
  Widget content(MediaSyncService syncService, MediaIndexService indexService,
      WebDavService webDavService) {
    return Column(
      children: [
        const Text('正在从云端同步资源...'),
        const SizedBox(height: 10),
        CircularProgressIndicator(
          color: Colors.blue[300],
          backgroundColor: Colors.blue[100],
          value: syncService.progress,
        ),
        const SizedBox(height: 10),
        Text(
          '${(syncService.progress * 100).toStringAsFixed(2)}%',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  @override
  Future<void> task(int nextStepIndex, MediaSyncService syncService,
      MediaIndexService indexService) async {
    ForegroundSyncService.updateNotification(
      desc: title,
    );

    try {
      final allObjects = indexService.mediaFiles;
      await syncService.syncFromCloud(allObjects);
    } catch (e) {
      syncService.errorMessage = '从云端同步资源失败: $e';
      return;
    }

    SyncStep.allSteps[nextStepIndex]
        .task(nextStepIndex + 1, syncService, indexService);
    syncService.currentStep += 1;
  }
}

class SyncToCloudStep implements SyncStep {
  @override
  Icon get icon => const Icon(Icons.cloud_upload_outlined);

  @override
  Icon get activeIcon => const Icon(Icons.cloud_upload_outlined);

  @override
  String get title => '上传资源到云端';

  @override
  Widget content(MediaSyncService syncService, MediaIndexService indexService,
      WebDavService webDavService) {
    return Column(
      children: [
        const Text('正在上传资源到云端...'),
        const SizedBox(height: 10),
        CircularProgressIndicator(
          color: Colors.blue[300],
          backgroundColor: Colors.blue[100],
          value: syncService.progress,
        ),
        const SizedBox(height: 10),
        Text(
          '${(syncService.progress * 100).toStringAsFixed(2)}%',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  @override
  Future<void> task(int nextStepIndex, MediaSyncService syncService,
      MediaIndexService indexService) async {
    ForegroundSyncService.updateNotification(
      desc: title,
    );
    final localObjects = indexService.localMediaFiles;
    try {
      await syncService.syncToCloud(localObjects);
    } catch (e) {
      syncService.errorMessage = '上传资源到云端失败: $e';
      return;
    }
    SyncStep.allSteps[nextStepIndex]
        .task(nextStepIndex + 1, syncService, indexService);
    syncService.currentStep += 1;
  }
}

class SyncCompletedStep implements SyncStep {
  @override
  Icon get icon => const Icon(Icons.check_circle_outlined);

  @override
  Icon get activeIcon => const Icon(Icons.check_circle_outlined);

  @override
  String get title => '同步完成';

  @override
  Widget content(MediaSyncService syncService, MediaIndexService indexService,
      WebDavService webDavService) {
    return Column(
      children: [
        const Text('同步完成'),
        const SizedBox(height: 10),
        FilledButton(
            onPressed: () {
              syncService.currentStep = 0;
            },
            child: const Text('重新同步')),
      ],
    );
  }

  @override
  Future<void> task(int nextStepIndex, MediaSyncService syncService,
      MediaIndexService indexService) async {
    syncService.errorMessage = '';
    await ForegroundSyncService.stopForegroundTask();
  }
}

class MediaSyncService extends ChangeNotifier {
  final WebDavService _webdavService;
  late Directory _appMediaDir;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;
  set errorMessage(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  // webdav上的图片，视频资源名
  Map<String, String> _cloudObjects = {};

  double _progress = 0.0;
  double get progress => _progress;
  set progress(double value) {
    _progress = value;
    debugPrint('当前同步进度: $_progress');
    notifyListeners();
  }

  /// 目前的同步步骤
  int _currentStep = 0;
  int get currentStep => _currentStep;
  set currentStep(int step) {
    _currentStep = step;
    debugPrint('当前同步步骤: $_currentStep');
    notifyListeners();
  }

  MediaSyncService(this._webdavService);

  static Future<MediaSyncService> builder(
    WebDavService webDavService,
  ) async {
    final service = MediaSyncService(webDavService);
    service._appMediaDir = await cloudMediaDirectory;
    return service;
  }

  /// 初始化WebDav目录
  Future<void> initWebDavDirectory() async {
    final uploadRootPath = _webdavService.uploadRootPath;
    if (await _webdavService.pathExists("$uploadRootPath/objects")) {
      return;
    }
    await _webdavService.createDirectory(uploadRootPath);
    await _webdavService.createDirectory("$uploadRootPath/objects");
  }

  /// 从WebDav服务更新资源对象列表
  Future<void> updateCloudObjects() async {
    final cloudObjects = await _fetchWebDavObjects(_webdavService);
    _cloudObjects = {for (var obj in cloudObjects) obj.hash: obj.name};
  }

  /// 删除云端资源
  Future<void> deleteCloudObject(MediaObject object) async {
    await _webdavService.deleteFile(
        "${_webdavService.uploadRootPath}/objects/${object.toString()}");
  }

  /// 下载云端资源到本地
  Future<void> syncFromCloud(Map<String, MediaAsset> allObjects) async {
    progress = 0.0;
    final List<MediaObject> objectsToDownload = _cloudObjects.entries
        .where((entry) => !allObjects.containsKey(entry.key))
        .map((entry) => MediaObject(entry.key, entry.value))
        .toList();

    final limit = PLimit<void>(await _maxConcurrentTasks);
    final taskLength = objectsToDownload.length;
    var finishedTasks = 0;
    final List<Future<void>> downloadTasks =
        objectsToDownload.map((object) async {
      await limit(() async {
        final filePath =
            "${_appMediaDir.path}${Platform.pathSeparator}${object.name}";
        if (await File(filePath).exists()) {
          return;
        }
        await _webdavService.downloadFile(
            "${_webdavService.uploadRootPath}/objects/${object.toString()}",
            filePath);
        finishedTasks += 1;
        progress = finishedTasks / taskLength;
      });
    }).toList();
    await Future.wait(downloadTasks);
  }

  /// 同步本地资源到WebDav
  /// 资源对象格式: {hash}_{name}
  Future<void> syncToCloud(Map<String, MediaAsset> localObjects) async {
    progress = 0.0;
    debugPrint('cloudObjects: $_cloudObjects');
    final List<_UploadMediaObject> objectsToUpload = localObjects.entries
        .where((entry) {
          return !_cloudObjects.containsKey(entry.key);
        })
        .map((entry) => _UploadMediaObject(
            MediaObject(entry.key, basename(entry.value.file.path)),
            entry.value.file))
        .toList();
    final limit = PLimit<void>(await _maxConcurrentTasks);
    final taskLength = objectsToUpload.length;
    var finishedTasks = 0;
    final List<Future<void>> uploadTasks = objectsToUpload.map((object) async {
      await limit(() async {
        if (await object.file.exists()) {
          debugPrint(
              '${object.file.path}->${_webdavService.uploadRootPath}/objects/${object.toString()}');
          await _webdavService.uploadFile(
              "${_webdavService.uploadRootPath}/objects/${object.toString()}",
              object.file);
        }
        finishedTasks += 1;
        progress = finishedTasks / taskLength;
      });
    }).toList();
    await Future.wait(uploadTasks).then((_) async {
      // 上传完成后更新云端对象列表
      await updateCloudObjects();
    });
  }
}

/// 从WebDav服务获取资源对象列表
/// 资源对象格式: {hash}_{name}.{ext}
Future<List<MediaObject>> _fetchWebDavObjects(WebDavService webDavService) {
  return webDavService
      .listDirectory("${webDavService.uploadRootPath}/objects")
      .then((list) => list
          .skip(1)
          .map((item) => MediaObject.fromString(item.name))
          .toList());
}

/// 最大并发上传/下载任务数
Future<int> get _maxConcurrentTasks async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('webdav_max_concurrent_tasks') ?? 5;
}

/// 获取应用专属媒体目录（存放从云端下载的文件）
Future<Directory> get cloudMediaDirectory async {
  Directory appDir;

  if (Platform.isAndroid || Platform.isIOS) {
    appDir = await getApplicationDocumentsDirectory();
  } else {
    appDir = await getApplicationSupportDirectory();
  }

  final mediaDir = Directory('${appDir.path}${Platform.pathSeparator}media');
  if (!await mediaDir.exists()) {
    await mediaDir.create(recursive: true);
  }

  return mediaDir;
}
