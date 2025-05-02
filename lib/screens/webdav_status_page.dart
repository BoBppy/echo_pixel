import 'package:easy_stepper/easy_stepper.dart';
import 'package:echo_pixel/services/media_index_service.dart';
import 'package:echo_pixel/services/media_sync_service.dart';
import 'package:echo_pixel/services/webdav_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WebDavStatusPage extends StatefulWidget {
  const WebDavStatusPage({super.key});

  @override
  State<StatefulWidget> createState() => _WebDavStatusPageState();
}

class _WebDavStatusPageState extends State<WebDavStatusPage> {
  late MediaIndexService _mediaIndexService;

  @override
  void initState() {
    super.initState();
    _mediaIndexService = context.read<MediaIndexService>();
  }

  @override
  Widget build(BuildContext context) {
    final mediaSyncService = context.watch<MediaSyncService>();
    final webDavService = context.watch<WebDavService>();
    final steps = SyncStep.allSteps;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 20),
          EasyStepper(
              showStepBorder: false,
              stepRadius: 25,
              activeStepTextColor: isDark ? Colors.white : Colors.black,
              activeStepIconColor: isDark ? Colors.white : Colors.black,
              finishedStepIconColor: isDark ? Colors.white : Colors.black,
              finishedStepTextColor: isDark ? Colors.white : Colors.black,
              unreachedStepIconColor:
                  isDark ? Colors.grey[600] : Colors.grey[400],
              unreachedStepTextColor: isDark ? Colors.white : Colors.black,
              activeStepBackgroundColor: mediaSyncService.errorMessage.isEmpty
                  ? (webDavService.isConnected
                      ? ((isDark ? Colors.yellow[600] : Colors.yellow[300]))
                      : isDark
                          ? Colors.grey[600]
                          : Colors.grey[400])
                  : (isDark ? Colors.red[600] : Colors.red[300]),
              finishedStepBackgroundColor:
                  isDark ? Colors.green[600] : Colors.green[300],
              unreachedStepBackgroundColor:
                  isDark ? Colors.grey[800] : Colors.grey[200],
              lineStyle: const LineStyle(
                lineType: LineType.normal,
                unreachedLineType: LineType.dotted,
              ),
              activeStep: mediaSyncService.currentStep,
              disableScroll: false,
              enableStepTapping: false,
              showScrollbar: false,
              titlesAreLargerThanSteps: false,
              steps: [
                for (final (index, step) in steps.indexed)
                  EasyStep(
                    icon: step.icon,
                    activeIcon: step.activeIcon,
                    title: index == mediaSyncService.currentStep
                        ? step.title
                        : null,
                  ),
              ]),
          Card.filled(
            color: isDark ? Colors.blue[300] : Colors.blue[100],
            margin: EdgeInsets.all(10),
            child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsetsGeometry.all(10),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Icon(
                            Icons.sync_outlined,
                            size: 18,
                            color: isDark ? Colors.grey[800] : Colors.grey[600],
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '同步状态',
                            style: TextStyle(
                              fontSize: 16,
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                          width: double.infinity,
                          child: mediaSyncService.errorMessage.isEmpty
                              ? Card.outlined(
                                  color: isDark
                                      ? Colors.blue[250]
                                      : Colors.blue[50],
                                  child: steps[mediaSyncService.currentStep]
                                      .content(mediaSyncService,
                                          _mediaIndexService, webDavService),
                                )
                              : Card.outlined(
                                  color: isDark
                                      ? Colors.red[300]
                                      : Colors.red[100],
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Text(
                                      mediaSyncService.errorMessage,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.red[800]
                                            : Colors.red[600],
                                      ),
                                    ),
                                  ),
                                )),
                      const SizedBox(height: 10),
                      Row(
                        spacing: 3,
                        children: [
                          Chip(
                            avatar: Icon(
                              size: 15,
                              Icons.rocket_launch_outlined,
                            ),
                            label: Text(
                              "当前步骤：${steps[mediaSyncService.currentStep].title}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                            shape: StadiumBorder(),
                            backgroundColor:
                                Colors.blueGrey.withValues(alpha: 0.1),
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.5),
                              width: 1.0,
                            ),
                          ),
                          Chip(
                            avatar: Icon(
                              size: 15,
                              webDavService.isConnected
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: webDavService.isConnected
                                  ? Colors.green[700]
                                  : Colors.red[700],
                            ),
                            label: Text(
                              "WebDav: ${webDavService.isConnected ? "已连接" : "未连接"}",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.black : Colors.grey[600],
                              ),
                            ),
                            shape: StadiumBorder(),
                            backgroundColor: webDavService.isConnected
                                ? isDark
                                    ? Colors.green[300]
                                    : Colors.green[100]
                                : isDark
                                    ? Colors.red[300]
                                    : Colors.red[100],
                            side: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.5),
                              width: 1.0,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                )),
          )
        ],
      ),
    );
  }
}
