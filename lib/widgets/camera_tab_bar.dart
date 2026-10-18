import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sound/sound_effects.dart';

/// iOSではSwiftUIのLiquid Glassを使う。その他の環境では通常の操作部品。
class CameraTabBar extends StatefulWidget {
  const CameraTabBar({
    super.key,
    this.selectedIndex = 1,
    this.onCamera,
    required this.onHistory,
    required this.onSettings,
  });

  final int selectedIndex;
  final VoidCallback? onCamera;
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
      SoundEffects.play(SoundEffect.tap);
      switch (call.arguments) {
        case 0:
          widget.onHistory();
        case 1:
          widget.onCamera?.call();
        case 2:
          widget.onSettings();
      }
    });
    _syncSelection();
  }

  Future<void> _syncSelection() async {
    await _channel?.invokeMethod<void>(
      'setSelectedIndex',
      widget.selectedIndex,
    );
  }

  @override
  void didUpdateWidget(covariant CameraTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) _syncSelection();
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
                  child: SizedBox(
                    width: 280,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _tab(
                          0,
                          '履歴',
                          Icons.calendar_month_outlined,
                          widget.onHistory,
                        ),
                        _tab(
                          1,
                          'カメラ',
                          Icons.camera_alt_outlined,
                          widget.onCamera ?? () {},
                        ),
                        _tab(
                          2,
                          '設定',
                          Icons.settings_outlined,
                          widget.onSettings,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    ),
  );
  Widget _tab(int index, String label, IconData icon, VoidCallback action) =>
      Expanded(
        child: Semantics(
          selected: widget.selectedIndex == index,
          child: TextButton(
            key: ValueKey('main-tab-$index'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              backgroundColor: widget.selectedIndex == index
                  ? const Color(0xFFFFE7D9)
                  : Colors.transparent,
            ),
            onPressed: action,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22),
                Text(label, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}
