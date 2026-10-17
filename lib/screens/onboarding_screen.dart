import 'dart:async';

import 'package:flutter/cupertino.dart'
    show
        CupertinoDatePicker,
        CupertinoDatePickerMode,
        CupertinoTextThemeData,
        CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../features/scan/ios_camera_permission_gate.dart';
import '../navigation/app_transitions.dart';
import '../services/notifications/daily_reminder_service.dart';
import '../services/sound/sound_effects.dart';
import '../services/settings/reminder_settings_store.dart';
import '../ui/asakao_style.dart';
import '../ui/asakao_widgets.dart';

/// OS のカメラ許可を求める。許可なら true、拒否なら false。
/// 事前に確認する手段がない端末（iOS 以外）では null を返し、最初の計測時に確認する。
Future<bool?> requestSystemCameraPermission() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return null;
  return IosCameraPermissionGate().request();
}

enum _Step {
  splash,
  intro,
  data,
  camera,
  cameraDenied,
  notify,
  notifyDenied,
  done,
}

enum _Camera { granted, denied, skipped, deferred }

/// 初回設定の流れ。カメラ・通知の許可が得られなくても最後まで進める。
/// 完了の保存は [onFinish] を受け取る呼び出し元が行う。
/// [explanationOnly] は「アプリの説明」の再表示用で、権限や設定には触れない。
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onFinish,
    this.reminderService,
    this.reminderStore,
    this.requestCameraPermission = requestSystemCameraPermission,
    this.explanationOnly = false,
    this.isSaving = false,
    this.saveError,
  }) : assert(
         explanationOnly || (reminderService != null && reminderStore != null),
       );

  final VoidCallback onFinish;
  final DailyReminderService? reminderService;
  final ReminderSettingsStore? reminderStore;
  final Future<bool?> Function() requestCameraPermission;
  final bool explanationOnly;
  final bool isSaving;
  final String? saveError;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _navigator = GlobalKey<NavigatorState>();

  /// 各ステップは入れ子の Navigator の別の経路にある。状態の変化はこれで再描画する。
  final _revision = ValueNotifier(0);
  _Camera _camera = _Camera.skipped;
  ReminderSettings? _reminder;
  DateTime _picked = DateTime(2000, 1, 1, const ReminderSettings().hour);
  bool _busy = false;
  String? _notifyError;

  void _set(VoidCallback change) {
    change();
    _revision.value++;
  }

  @override
  void didUpdateWidget(covariant OnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _revision.value++; // 保存中・保存エラーの表示を最後の画面へ反映する。
  }

  @override
  void dispose() {
    _top.dispose();
    _revision.dispose();
    super.dispose();
  }

  /// 表示中の段階。上のドット（1-2〜1-4）は遷移の外に置き、この値で動かす。
  late final _top = ValueNotifier(
    widget.explanationOnly ? _Step.intro : _Step.splash,
  );
  late final _observer = _StepObserver((step) {
    // Navigator の更新中に通知されるため、描画は次のマイクロタスクで反映する。
    scheduleMicrotask(() {
      if (mounted) _top.value = step;
    });
  });

  int? _dotFor(_Step step) => switch (step) {
    _Step.intro => 0,
    _Step.data => 1,
    _Step.camera => 2,
    _ => null,
  };

  Route<void> _route(_Step step, {bool push = false}) {
    Widget page(BuildContext _) => Material(
      color: AsakaoStyle.background,
      child: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: _revision,
          builder: (_, _, _) => _page(step),
        ),
      ),
    );
    final settings = RouteSettings(name: step.name, arguments: step);
    return push
        ? AppTransitions.push(page, settings: settings)
        : AppTransitions.fade(page, settings: settings);
  }

  /// 同じ場所で入れ替える（fade）。
  void _go(_Step step) {
    _navigator.currentState?.pushReplacement(_route(step));
    if (step == _Step.done) SoundEffects.play(SoundEffect.setupDone); // 1-7
  }

  /// 右から入る（push）。左端スワイプで戻れる。
  void _push(_Step step) =>
      _navigator.currentState?.push(_route(step, push: true));

  Future<void> _requestCamera() async {
    if (_busy) return;
    _set(() => _busy = true);
    bool? granted;
    try {
      granted = await widget.requestCameraPermission();
    } catch (_) {
      granted = null; // 確認できなければ最初の計測時に確認する。
    }
    if (!mounted) return;
    _set(() {
      _busy = false;
      _camera = switch (granted) {
        true => _Camera.granted,
        false => _Camera.denied,
        null => _Camera.deferred,
      };
    });
    granted == false ? _go(_Step.cameraDenied) : _push(_Step.notify);
  }

  /// 許可 → 予約 → 保存の順。設定画面と同じ流れで、失敗してもここで止まらない。
  Future<void> _setReminder() async {
    if (_busy) return;
    final service = widget.reminderService!;
    final next = ReminderSettings(
      enabled: true,
      hour: _picked.hour,
      minute: _picked.minute,
    );
    _set(() {
      _busy = true;
      _notifyError = null;
    });
    _Step? step;
    String? error;
    try {
      if (await service.requestPermission()) {
        await service.scheduleDaily(next.hour, next.minute);
        try {
          await widget.reminderStore!.save(next);
        } catch (_) {
          // 保存できないなら予約も残さない（表示と実際をそろえる）。
          try {
            await service.cancel();
          } catch (_) {}
          rethrow;
        }
        _reminder = next;
        step = _Step.done;
      } else {
        step = _Step.notifyDenied;
      }
    } catch (_) {
      error = '通知を設定できませんでした。スキップして、あとから設定でも変更できます。';
    }
    if (!mounted) return;
    _set(() {
      _busy = false;
      _notifyError = error;
    });
    if (step != null) _go(step);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AsakaoStyle.background,
    body: Stack(
      children: [
        Navigator(
          key: _navigator,
          observers: [_observer],
          onGenerateInitialRoutes: (_, _) => [
            _route(widget.explanationOnly ? _Step.intro : _Step.splash),
          ],
        ),
        // 1-2〜1-4 のドットは画面と一緒に動かさず、その場で切り替える。
        SafeArea(
          child: SizedBox(
            height: 56,
            child: Center(
              child: ValueListenableBuilder(
                valueListenable: _top,
                builder: (_, step, _) {
                  final dot = _dotFor(step);
                  return AnimatedOpacity(
                    duration: AppTransitions.fadeDuration,
                    opacity: dot == null ? 0 : 1,
                    child: AsakaoStepDots(
                      count: widget.explanationOnly ? 2 : 3,
                      index: dot ?? 0,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _page(_Step step) => switch (step) {
    _Step.splash => _splash(),
    _Step.intro => _intro(),
    _Step.data => _data(),
    _Step.camera => _cameraPage(),
    _Step.cameraDenied => _denied(
      title: 'カメラがオフです',
      body: 'あさかおはカメラで顔の様子を読み取って記録します。オフのままでは計測できません。',
      steps: const ['端末の「設定」アプリを開く', '「あさかお」の「カメラ」のスイッチをオンにする', 'あさかおに戻る'],
      action: 'あとで設定する',
      onNext: () => _push(_Step.notify),
    ),
    _Step.notify => _notify(),
    _Step.notifyDenied => _denied(
      title: '通知がオフです',
      body: '朝のお知らせは届きませんが、チェックはアプリからいつでもできます。あとから設定アプリでオンにできます。',
      steps: const ['端末の「設定」アプリを開く', '「あさかお」の「通知」で「通知を許可」をオンにする', 'あさかおに戻る'],
      action: '通知なしで進む',
      onNext: () => _go(_Step.done),
    ),
    _Step.done => _done(),
  };

  // ---- 共通の枠 ----

  /// 下のボタンは画面が出てから少し遅れて現れる。
  static const _actionsDelay = Duration(milliseconds: 350);

  /// 上の 56px はドットの場所（ドット自体は [build] で画面の外側に置く）。
  Widget _frame({
    Widget? topRight,
    required List<Widget> body,
    required List<Widget> actions,
    CrossAxisAlignment align = CrossAxisAlignment.center,
    Duration actionsDelay = _actionsDelay,
  }) => Column(
    children: [
      SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (topRight != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: topRight,
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: Column(crossAxisAlignment: align, children: body),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: AsakaoReveal(
          delay: actionsDelay,
          rise: 0, // ボタンはその場でフェードインする
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: actions,
          ),
        ),
      ),
    ],
  );

  Widget _heading(String title, {TextAlign align = TextAlign.center}) =>
      Semantics(
        header: true,
        child: Text(title, textAlign: align, style: AsakaoStyle.title),
      );

  Widget _lead(String text, {TextAlign align = TextAlign.center}) => Text(
    text,
    textAlign: align,
    style: AsakaoStyle.body.copyWith(color: AsakaoStyle.muted),
  );

  // ---- 1-1 スプラッシュ ----

  Widget _splash() => Semantics(
    button: true,
    label: 'タップしてはじめる',
    excludeSemantics: true,
    child: InkWell(
      onTap: () => _go(_Step.intro),
      child: SizedBox.expand(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AsakaoMascot(size: 160),
                      const SizedBox(height: 24),
                      const Text('あさかお', style: AsakaoStyle.title),
                      const SizedBox(height: 4),
                      Text(
                        '毎朝15秒の体調記録',
                        style: AsakaoStyle.body.copyWith(
                          color: AsakaoStyle.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Text('タップしてはじめる', style: AsakaoStyle.caption),
            ),
          ],
        ),
      ),
    ),
  );

  // ---- 1-2 アプリ紹介 ----

  Widget _intro() => _frame(
    body: [
      const SizedBox(height: 24),
      SizedBox.square(
        dimension: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const ExcludeSemantics(
              child: SizedBox.expand(
                child: CircularProgressIndicator(
                  value: 0.25,
                  strokeWidth: 12,
                  backgroundColor: AsakaoStyle.coralPale,
                  valueColor: AlwaysStoppedAnimation(AsakaoStyle.coral),
                ),
              ),
            ),
            const AsakaoMascot(size: 120),
            Positioned(
              top: 4,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AsakaoStyle.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AsakaoStyle.border),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    '15秒',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AsakaoStyle.coralInk,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 32),
      _heading('毎朝15秒で\n体調を記録する'),
      const SizedBox(height: 16),
      _lead('顔をカメラに15秒向けるだけ。\n3日分そろうと、普段との違いを比べられます。'),
    ],
    actions: [
      AsakaoPrimaryButton(label: 'つづける', onPressed: () => _push(_Step.data)),
    ],
  );

  // ---- 1-3 データの扱い ----

  Widget _chip(String text, {bool highlight = false}) => DecoratedBox(
    decoration: BoxDecoration(
      color: highlight ? AsakaoStyle.coralPale : AsakaoStyle.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: highlight ? AsakaoStyle.coralPale : AsakaoStyle.border,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: highlight ? AsakaoStyle.coralInk : AsakaoStyle.ink,
        ),
      ),
    ),
  );

  Widget _point(String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: AsakaoStyle.body.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(body, style: AsakaoStyle.body.copyWith(color: AsakaoStyle.muted)),
    ],
  );

  Widget _data() => _frame(
    align: CrossAxisAlignment.start,
    body: [
      const SizedBox(height: 16),
      _heading('データの扱い', align: TextAlign.start),
      const SizedBox(height: 24),
      Text(
        '画像は保存しません',
        style: AsakaoStyle.heading.copyWith(
          fontSize: 22,
          color: AsakaoStyle.coralInk,
        ),
      ),
      const SizedBox(height: 8),
      const Text('撮影した映像はその場で解析して破棄します。写真は残りません。', style: AsakaoStyle.body),
      const SizedBox(height: 12),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _chip('カメラで15秒'),
          const Icon(Icons.chevron_right, size: 16, color: AsakaoStyle.muted),
          _chip('端末で解析'),
          const Icon(Icons.chevron_right, size: 16, color: AsakaoStyle.muted),
          _chip('記録だけ保存', highlight: true),
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(),
      ),
      _point('記録はこの端末の中だけ', '外部には送信しません。アカウント登録も不要です。'),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Divider(),
      ),
      _point('診断には使えません', 'セルフチェックの記録用です。体調が気になるときは医療機関に相談してください。'),
    ],
    actions: [
      AsakaoPrimaryButton(
        label: widget.explanationOnly ? '閉じる' : '同意してつづける',
        onPressed: widget.explanationOnly
            ? widget.onFinish
            : () => _push(_Step.camera),
      ),
    ],
  );

  // ---- 1-4 カメラ ----

  Widget _cameraPage() => _frame(
    body: [
      const SizedBox(height: 24),
      Stack(
        clipBehavior: Clip.none,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: AsakaoStyle.card,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(40),
              child: AsakaoMascot(size: 140),
            ),
          ),
          Positioned(
            right: -8,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AsakaoStyle.link,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Icon(Icons.photo_camera_outlined, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 32),
      _heading('カメラを使います'),
      const SizedBox(height: 16),
      _lead('顔の明るさと角度を確かめて15秒間の様子を読み取ります。映像は保存も送信もしません。'),
    ],
    actions: [
      const Text(
        '許可の確認が表示されたら「許可」を選んでください',
        textAlign: TextAlign.center,
        style: AsakaoStyle.caption,
      ),
      const SizedBox(height: 8),
      AsakaoPrimaryButton(
        label: 'カメラを許可する',
        onPressed: _busy ? null : _requestCamera,
      ),
      AsakaoTextLink(
        label: '今はしない',
        onPressed: _busy
            ? null
            : () {
                _set(() => _camera = _Camera.skipped);
                _go(_Step.cameraDenied);
              },
      ),
    ],
  );

  // ---- 1-5 / 1-6' 許可がオフのとき ----

  Widget _denied({
    required String title,
    required String body,
    required List<String> steps,
    required String action,
    required VoidCallback onNext,
  }) => _frame(
    align: CrossAxisAlignment.start,
    body: [
      const Align(
        alignment: Alignment.centerLeft,
        child: AsakaoMascot(mood: AsakaoMascotMood.sad, size: 96),
      ),
      const SizedBox(height: 16),
      _heading(title, align: TextAlign.start),
      const SizedBox(height: 12),
      _lead(body, align: TextAlign.start),
      const SizedBox(height: 24),
      AsakaoNumberedSteps(title: '設定アプリでオンにする方法', steps: steps),
    ],
    actions: [AsakaoPrimaryButton(label: action, onPressed: onNext)],
  );

  // ---- 1-6 通知の時刻 ----

  Widget _notify() => _frame(
    topRight: AsakaoTextLink(
      label: 'スキップ',
      onPressed: _busy ? null : () => _go(_Step.done),
    ),
    align: CrossAxisAlignment.start,
    body: [
      _heading('通知の時刻', align: TextAlign.start),
      const SizedBox(height: 12),
      _lead('1日1回、決めた時刻に届きます。\n設定からいつでも変更できます。', align: TextAlign.start),
      const SizedBox(height: 24),
      AsakaoCard(
        child: Column(
          children: [
            const Text(
              '通知する時刻',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AsakaoStyle.muted,
              ),
            ),
            SizedBox(
              height: 180,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: TextStyle(
                      fontSize: 22,
                      color: AsakaoStyle.ink,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: _picked,
                  onDateTimeChanged: (value) => _picked = value,
                ),
              ),
            ),
          ],
        ),
      ),
      if (_notifyError != null) ...[
        const SizedBox(height: 12),
        Text(
          _notifyError!,
          style: AsakaoStyle.body.copyWith(color: AsakaoStyle.poorInk),
        ),
      ],
    ],
    actions: [
      AsakaoPrimaryButton(
        label: '設定する',
        onPressed: _busy ? null : _setReminder,
      ),
    ],
  );

  // ---- 1-7 準備ができました ----

  Widget _status(String text, {required bool ok}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AsakaoStyle.linkPale,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              ok ? Icons.check : Icons.remove,
              size: 14,
              color: AsakaoStyle.link,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            text,
            style: AsakaoStyle.body.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _done() {
    final cameraText = switch (_camera) {
      _Camera.granted => 'カメラ：許可済み',
      _Camera.deferred => 'カメラ：最初の計測時に確認します',
      _Camera.denied || _Camera.skipped => 'カメラ：未許可',
    };
    final reminder = _reminder;
    return _frame(
      body: [
        const SizedBox(height: 24),
        const AsakaoMascot(mood: AsakaoMascotMood.happy, size: 160),
        const SizedBox(height: 24),
        _heading('準備ができました'),
        const SizedBox(height: 16),
        _lead('記録が3日分そろうと、普段との違いを比べられます。'),
        const SizedBox(height: 24),
        // 画面が切り替わってから、1行ずつ下からフェードインする。
        AsakaoReveal(
          delay: const Duration(milliseconds: 400),
          child: _status(cameraText, ok: _camera == _Camera.granted),
        ),
        AsakaoReveal(
          delay: const Duration(milliseconds: 600),
          child: _status(
            reminder == null ? '通知：オフ' : '通知：毎朝 ${reminder.timeLabel}',
            ok: reminder != null,
          ),
        ),
        if (widget.saveError != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.saveError!,
            textAlign: TextAlign.center,
            style: AsakaoStyle.body.copyWith(color: AsakaoStyle.poorInk),
          ),
        ],
      ],
      actionsDelay: const Duration(milliseconds: 900),
      actions: [
        AsakaoPrimaryButton(
          label: widget.isSaving ? '保存中…' : '記録をはじめる',
          onPressed: widget.isSaving ? null : widget.onFinish,
        ),
      ],
    );
  }
}

/// 入れ子の Navigator の一番上の段階を知らせる（左端スワイプで戻ったときも含む）。
class _StepObserver extends NavigatorObserver {
  _StepObserver(this.onTop);

  final void Function(_Step step) onTop;

  void _notify(Route<dynamic>? route) {
    final step = route?.settings.arguments;
    if (step is _Step) onTop(step);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notify(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notify(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _notify(newRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _notify(previousRoute);
}
