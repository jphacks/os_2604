import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:os_2604/services/settings/feedback_settings_store.dart';
import 'package:os_2604/services/sound/sound_effects.dart';
import 'package:os_2604/ui/tap_feedback.dart';

void main() {
  late List<SoundEffect> played;
  late List<AppHaptic> felt;
  setUp(() {
    played = [];
    felt = [];
    SoundEffects.settings = const FeedbackSettings();
    SoundEffects.debugOnPlay = played.add;
    SoundEffects.debugOnHaptic = felt.add;
  });
  tearDown(() {
    SoundEffects.debugOnPlay = null;
    SoundEffects.debugOnHaptic = null;
  });

  Future<void> pump(WidgetTester tester, Widget body) => tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => TapFeedback(child: child!),
      home: Scaffold(body: body),
    ),
  );

  testWidgets('enabled buttons tap with sound and a short vibration', (
    tester,
  ) async {
    var pressed = 0;
    await pump(
      tester,
      Column(
        children: [
          FilledButton(onPressed: () => pressed++, child: const Text('押せる')),
          const FilledButton(onPressed: null, child: Text('押せない')),
          const Text('ただの文字'),
        ],
      ),
    );
    await tester.tap(find.text('押せる'));
    expect(pressed, 1);
    expect(played, [SoundEffect.tap]);
    expect(felt, [AppHaptic.tick]);

    await tester.tap(find.text('押せない'), warnIfMissed: false);
    await tester.tap(find.text('ただの文字'));
    expect(played, [SoundEffect.tap]); // 押せない所では鳴らない
  });

  testWidgets('switches, plain tap areas and list rows count, once each', (
    tester,
  ) async {
    await pump(
      tester,
      Column(
        children: [
          Switch.adaptive(value: true, onChanged: (_) {}),
          GestureDetector(onTap: () {}, child: const Text('タップ領域')),
          InkWell(onTap: () {}, child: const Text('行')),
        ],
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('タップ領域'));
    await tester.tap(find.text('行'));
    expect(played, [SoundEffect.tap, SoundEffect.tap, SoundEffect.tap]);
  });

  testWidgets('scrolling over a button does not tap', (tester) async {
    await pump(
      tester,
      ListView(
        children: [
          for (var i = 0; i < 30; i++)
            TextButton(onPressed: () {}, child: Text('行 $i')),
        ],
      ),
    );
    await tester.drag(find.text('行 3'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(played, isEmpty);
  });

  testWidgets('sound and vibration follow the settings', (tester) async {
    SoundEffects.settings = const FeedbackSettings(sound: false);
    await pump(tester, FilledButton(onPressed: () {}, child: const Text('押す')));
    await tester.tap(find.text('押す'));
    expect(played, isEmpty);
    expect(felt, [AppHaptic.tick]);
  });
}
