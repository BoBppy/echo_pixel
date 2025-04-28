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

    return Column(
      children: [
        EasyStepper(
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
                  title:
                      index == mediaSyncService.currentStep ? step.title : null,
                ),
            ]),
        const SizedBox(height: 20),
        steps[mediaSyncService.currentStep]
            .content(mediaSyncService, _mediaIndexService, webDavService),
      ],
    );
  }
}
