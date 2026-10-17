import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// iOSではSwiftUIのLiquid Glassを使う。その他の環境では通常の操作部品。
class CameraTabBar extends StatefulWidget {
  const CameraTabBar({
    super.key,
    required this.onHistory,
    required this.onSettings,
  });

  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  State<CameraTabBar> createState() => _CameraTabBarState();
}

class _CameraTabBarState extends State<CameraTabBar> {
  MethodChannel? _channel;

  void _created(int id) {
    final channel = MethodChannel('os2604/camera-tabs/$id');
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted || call.method != 'selectTab') return;
      switch (call.arguments) {
        case 0:
          widget.onHistory();
        case 2:
          widget.onSettings();
      }
    });
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 12),
    child: SizedBox(
      height: 80,
      child: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
          ? UiKitView(
              viewType: 'os2604/camera-tabs',
              onPlatformViewCreated: _created,
            )
          : Center(
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(40),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: widget.onHistory,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('履歴'),
                      ),
                      Semantics(
                        selected: true,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            semanticLabel: 'カメラ',
                            size: 30,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: widget.onSettings,
                        icon: const Icon(Icons.settings_outlined),
                        label: const Text('設定'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
