# 現在の作業状態

## 2026-10-17 P2（30fps分離RGBサンプリング・rPPG・顔色特徴量）および B担当DB/履歴・P1 Swift Foundation Models 統合検証

- 作業ブランチ：`rppg_accuracy_validation_integration`（`origin/c` `0e3d79a` を取り込み、BのDB/画面・カメラタブUI・P1 Swift Foundation ModelsブリッジとP2を統合）。
- 実装内容：
  1. **顔検出間引き（180ms）・4倍縮小検出バッファと分離した30fps RGBサンプリング**：
     - `lib/features/scan/experimental_face_signals.dart` に `faceDetectionInterval: Duration(milliseconds: 180)`、`faceDetectionDownsampleFactor: 4`、`downsampleBgra8888ForDetection`、`stabilizeFaceRegion`（3%デッドバンド）、`ShootingConditionSummary.effectiveFps` を実装。
     - `lib/features/scan/ios_camera_frame_source.dart` で ML Kit 実行中（`_busy`）および間引き間隔内のカメラフレームからフル解像度BGRAの内側皮膚ROI平均RGBを `_pendingRgbSamples` に30fpsで採取し、次の `ScanObservation.rgbSamples` で時系列順に `HealthScanController` へ引き渡す。P2有効時は `ExposureMode.locked` をベストエフォート適用。
     - `lib/main.dart` の `_createSession` を `CameraScanService(configuration: ScanConfiguration.day1Experimental())` に接続。
  2. **B担当DB・結果/履歴画面・P1オンデバイスAIとの統合テスト**：
     - `test/bc_integration_test.dart` にP2推定値（`estimatedHeartRateBpm`・`HeartRateSource.rppgExperimental`・`faceColorFeature`）の計測直後DB保存、`ResultScreen` 表示（`心拍数は試験的な推定値です`・`顔色特徴量`）、`OnDeviceAiRunner`（`ReportMode.onDevice`）レポート生成、`HistoryScreen` 一覧から詳細再表示までの統合テストを追加。
- 自動検証・実機導入結果：
  - `dart format --output=none --set-exit-if-changed lib test`：73ファイル変更なし。
  - `flutter analyze --no-pub`：指摘なし（0 issues）。
  - `flutter test --no-pub`：全274件成功。
  - 実機ビルド・導入：physical iPhone 17（`00008150-000268A03EC2401C`、iOS 27.0.1）へ統合版 iOS Release ビルド（61.0MB）をインストール・起動成功。
- 実機手動確認結果（physical iPhone 17 / iOS 27.0.1 + Apple Watch 同時比較）：
  1. **30fps分離RGBサンプリング＋間引き顔検出によるrPPG同時比較**：従来の同期 `FaceDetectorMode.accurate`（約6fps・約90サンプル）では `minRppgSamples: 120` により `null` フォールバックしていた問題が解消され、実機15秒計測で `minRppgSamples: 120` およびスペクトルSNR閾値をクリアして試験的心拍数推定値が表示されること、同時に計測した Apple Watch の基準値と近接した値（差6bpm程度）となることを確認（`AGENTS.md` のプライバシー規定に従い、個人の測定実数値はログ・Gitに含めない）。
  2. **B担当DB保存・履歴画面およびP1レポート作成・保存の統合確認**：実機上で15秒計測後のDB保存、結果画面での表示、レポート作成と保存が正常に完了することを確認。

## 2026-10-17 B/C 最終統合（Foundation Models ブリッジ・過去比較・schema v4 実機移行確認・カメラタブUI）

- 作業ブランチ：`manual_ui_testing_migration`（`origin/main` `6a70610` と `origin/codex/b-camera-tab-ui` `1be6191` を統合）。
- 実装・統合内容：
  1. **過去比較のレポート本文接続**：`ResultScreen._generateReport` で記録日基準の直近7暦日（当日を除く）の有効記録から `calculateHistoryBaseline` を算出し、`OnDeviceAiRunner.generateReflection(scan, baseline: baseline)` と `TemplateRecordSummary` へ接続。履歴不足時は「過去比較：基準値蓄積中（有効記録 X/3件 または 体調の記録 X/3件）」、有効記録3件以上かつ体調入力3件以上では「過去比較：直近7日間（今日を除く）の体調の中央値 ...」をレポート本文（端末内AI・定型文とも）に表示。基準値成立時はAI短文選択キー `reviewHistoryComparison` も許可。
  2. **Swift 側の Foundation Models ブリッジ実装**：`ios/Runner/AppDelegate.swift` に `jp.jphacks.os_2604/on_device_ai` チャネルと `OnDeviceAiBridge` を実装。`SystemLanguageModel.default.availability`・日本語ロケール対応確認、`LanguageModelSession` による短文キー生成、requestId 単位の `Task` 管理・キャンセル・単発完了保証（`PendingGeneration`）、iOS 26 `GenerationError` / iOS 27 `LanguageModelError`・`SystemLanguageModel.Error` のエラーコード変換を接続。
  3. **B側 カメラ起点タブUI（`origin/codex/b-camera-tab-ui` `1be6191`）の統合**：`AppDelegate.swift` に `CameraTabBar`、`CameraPermissionBridge`、`OnDeviceAiBridge` の3つすべてを登録。
- 統合後の自動検証・実機導入：`dart format --output=none --set-exit-if-changed lib test` は71ファイル変更なし、`flutter analyze --no-pub` 指摘なし、`flutter test --no-pub --reporter expanded` 全257件成功。署名付き iOS Release ビルド（`build/ios/iphoneos/Runner.app` 61.0MB）成功、physical iPhone 17（`00008150-000268A03EC2401C`）に `com.example.os2604` を上書き導入・起動成功。
- DB移行（schema v4）の実機検証（physical iPhone 17 / iOS 27.0.1、`00008150-000268A03EC2401C`）：
  - 本体アプリ（`com.example.os2604`）の実測履歴を汚染しないよう、分離バンドル `com.example.os2604.permissioncheck` のコンテナに `PRAGMA user_version = 3`・2026年Unix秒値（`measured_at = 1792219200`）・`reminder_preferences`（`7:30` ON）・`onboarding_completions` を持つ SQLite ファイルを配置して実機起動。
  - 実機上の `AppDatabase.onUpgrade(3 -> 4)` により、`user_version = 4`、`measured_at = 1792219200000000`（マイクロ秒）、`elapsed_micros = 15000000`、`quality = 'good'`、`reminder_preferences` がすべて保持・変換されることを実機で確認。確認後、`com.example.os2604.permissioncheck` は実機からアンインストールし、端末上にテスト用データが残らない状態に清掃済み。
- 実機手動UI確認（physical iPhone 17 / iOS 27.0.1）：ユーザーから「1. 実機での手動UI確認が完了しました」と報告を受領（① 初回カメラ許可ダイアログ確認、② オンデバイスAI／定型文フォールバック・過去比較レポート表示、③ 撮影中断・体調/体温入力解除と保存・履歴・削除・通知設定、④ オフラインデモ確認）。翌日の通知繰り返しは当日外のため未確認として区別。

## 2026-10-17 カメラタブUIとSwiftUI Liquid Glass（origin/codex/b-camera-tab-ui 1be6191）

- ブランチ：`codex/b-camera-tab-ui`、main `cc33313` から作成。サブエージェント不使用。
- AのFigJamをChromeで確認。白背景・オレンジ・下部の履歴／カメラ／設定を参考に、HomeScreenをカメラタブの入口として変更。本文はデザイン未確定のため既存の開始・保存済み状態・説明導線を維持。
- iOSの下部メニューはFlutter UiKitView + UIHostingControllerでSwiftUIを埋め込む。iOS 26以降は純正glassEffect、旧iOSはultraThinMaterial。iOS以外はFlutter部品。履歴・設定は既存の画面遷移を使用し、この段階では各遷移先への共通タブ化はしない。
- 変更：lib/screens/home_screen.dart、lib/widgets/camera_tab_bar.dart、ios/Runner/CameraTabBar.swift、AppDelegate.swift、Runner.xcodeproj。Cの計測・AI内部、DB、通知のロジックは変更なし。
- 確認：整形65ファイル変更なし、flutter analyze指摘なし、全237テスト成功（画面遷移・小画面／文字拡大含む）、署名付きiOS Releaseビルド成功60.5MB。
- iPhone 15 / iOS 26.6.2へインストール・起動成功。ネイティブメニューの見た目・タップのユーザー確認は未実施。iPhone17も未確認。
- 追加変更：ユーザー要望によりMainTabsScreen + IndexedStackへ変更。履歴／カメラ／設定を経路pushせず即座に切り替え、下部メニューを常時表示。履歴・設定のタブ内では戻る矢印を非表示。既存の単独ルートは互換性のため維持。
- SwiftUI側はObservableObjectに選択タブを保持し、MethodChannelでFlutterの選択状態と同期。Flutter代替メニューも3タブすべて選択可能。
- タブ切替・選択表示・戻る矢印なしを既存の画面遷移テストで確認。追加変更後も全237テスト成功、静的解析指摘なし。
- タブ切替版もiOS Releaseビルド成功（60.5MB）、iPhone 15へインストール成功。実機のタブ操作はユーザー確認待ち。mainへは未マージ。
- 追加の見た目調整：ユーザーの参考画像に合わせ、全幅に近い暗い半透明カプセル、中央の白丸カメラ、左右の白いアイコン／文字へ変更。3タブの機能は維持。
- 選択インジケーターはiOS26以降のGlassEffectContainer + glassEffectを使用した単一カプセルを横移動し、springでアニメーション。アクセシビリティの視差効果を減らす設定では移動アニメーションを無効化。旧iOSは半透明カプセルへフォールバック。
- アニメーション調整後の確認：iOS Releaseビルド成功60.6MB、iPhone15にインストール・起動成功。SwiftUIのみの描画変更のため全Flutterテストは再実行せず、直前の237件成功を保持。実機での見た目・動きはユーザー確認待ち。
- デザイン訂正：参考画像は中央のカメラボタンだけに適用するとのユーザー指示。暗い全幅バーを撤回し、明るいコンパクトなバーと茶色の選択色へ戻す。中央の白丸カメラ、タブ切替、ガラスのスライドアニメーションは維持。訂正版もiOS Releaseビルド成功（60.6MB）、iPhone15へインストール・起動成功。
- フッター背景の修正：外側Scaffoldの背景色を選択タブに合わせる。カメラは既存の白、履歴・設定はテーマのscaffoldBackgroundColor。タブ内画面との色の境目を解消。画面遷移・ホームの7テスト成功、静的解析指摘なし、整形チェック成功。iOS Releaseビルド成功60.6MB、iPhone15へインストール成功。

## 2026-10-17 B 受け入れ確認（origin/main cc33313）

- ブランチ：`codex/b-acceptance-checks`。基点 main `5d591c5`（PR #6 最終統合済み）。iPhoneに導入した統合版とのコード差分なし。
- 自動確認：統合版の全237テスト成功、整形64ファイル変更なし、静的解析指摘なし。iOS Releaseビルド成功（60.4MB）。main統合後のコード変更がないため同じ確認は再実行していない。
- 実機：iPhone 15 / iOS 26.6.2 にインストール・起動成功。ユーザーが通知を確認できたと報告し、通常動作も良好と報告。
- 実機合格（ユーザー「未測定や。全部合格」）：体調・体温を解除して保存し再起動後も未入力／未測定、通知タップ起動、通知時刻変更後の配信、オフによる取消。翌日の繰り返しは未確認。
- 実機合格（ユーザー「全部できた」）：計測中の顔外れ→失敗・再試行・履歴に増えない、アプリ離脱→中断・再試行、機内モードかつWi-Fiオフで計測・保存・レポートを2回。
- カメラ権限拒否・暗所・個別／全件削除：ユーザー「全部いけてる思うよ」と報告。ユーザー確認で問題なし（画面・ログの独立確認は未実施）。
- 残り：翌日の通知繰り返し、本番対象iPhone 17での最終確認。
- ユーザーから結果を受け取った項目だけ確定し、未回答項目は未確認のまま残す。

## 以下は過去の引き継ぎ記録（現状は上記を優先）

## 2026-10-17 c：B/C統合と実機導入（手動確認待ち）

## 2026-10-17 c：高優先の互換性・権限修正

- ユーザー依頼：残課題の高優先から進め、cへ切替。現在のフェーズはユーザー回答でDay 1。
- 現在地：/Users/shindenfuta/JPHACKS、ブランチc。origin/c 47578c3から作成後、origin/main 0e4b1ffへfast-forward。main・リモートへのpush/マージなし。ユーザーから今回の修正を一旦コミットする依頼を受領。本STATEを含む修正を1コミットにまとめる。pushは依頼されていない。
- 保護：元のcodex/bc-device-checkの未コミットSTATEはstash「preserve bc device verification state before switching to c」に保存して保持。未追跡Word/PDF4文書、Git除外の個人署名設定、別worktreeの未コミットSTATEは変更していない。
- 前回の実機試験の正本：/Users/shindenfuta/.codex/worktrees/latest-main-device-check/JPHACKS/.codex/STATE.md（955f1bb）。通常計測/即保存/任意入力/定型文/履歴/個別全件削除/再起動保持/顔外れ/離脱/権限OFF/暗所/オフラインはユーザー手動確認済み。今回の変更後や通知追加版の実機合格へ読み替えない。

## 今回の変更・合意

- DB：schema v4。ユーザーは「2026年の秒値だけ変換する」と承認。UTC 2026-01-01以上・2027-01-01未満に相当するUnix秒値だけを100万倍し、その他の値は保持。v2/v3の秒・マイクロ秒混在、二重変換を防ぐ。
- 移行はテーブル追加・日時変換を同一トランザクションで実行。失敗は伝播し、DB削除/再作成なし。ID・NULL・実経過・出典・入力・レポート・説明確認・既存通知設定を保護する。単位情報がなく、対象外期間の旧秒値や同じ整数になる1970年付近のマイクロ秒値は完全判別できない。対象範囲の追加は別途判断。
- カメラ：iOS権限確認を初期化より前に分離。AppDelegateに独自camera_permissionチャネルを登録。ScanPhase.requestingPermissionと撮影画面の確認中表示を追加。
- 許可ダイアログ中のinactiveは待機。許可とresumedの両方を確認してからカメラ初期化。OS回答待ちは初期化の10秒制限・計測の15秒に含めない。背景化/画面離脱/計測中のinactiveは中断。拒否はpermissionDenied、チャネル失敗はcameraUnavailable。キャンセル後の遅い応答は破棄する。
- iOS AppDelegate変更の対象・理由・影響をユーザーへ提示済み。依存・権限用途文・音声権限・main.dartは変更なし。
- 重複回避：origin/codex/b-result-inputs 4bbc022とorigin/codex/b-scan-navigation e6a0a53にB側の修正がある。結果入力と撮影ナビゲーション競合は重複実装せず、今回のscan_screen変更は進捗表示1行だけ。
- 通知：PR #5がmain 0e4b1ffへ統合済みでcにも含む。前の「通知未実装」という一覧は古い。今回pod installと通知依存を含むiOSビルドが成功。配信の実機試験は未実施。

## 変更ファイル

- lib/services/db/app_database.dart（schema v4・限定日時移行）
- lib/features/scan/camera_scan_service.dart、health_scan_controller.dart、scan_widget.dart、新規scan_permission_gate.dart・ios_camera_permission_gate.dart
- lib/models/scan_contract.dart、lib/screens/scan_screen.dart、ios/Runner/AppDelegate.swift
- 新規test/services/db/legacy_timestamp_migration_test.dart、health_record_store_test.dart（v1 fixtureを本来の単一テーブルへ修正）
- test/features/scan/health_scan_controller_test.dart、scan_widget_test.dart、新規ios_camera_permission_gate_test.dart
- README.md、docs/implementation-decisions.md、docs/c-integration.md、このSTATE

## 検証

- Flutter 3.47.7 / Dart 3.13.5。最新mainの通知依存が一時キャッシュに不足したためpub getで解決。pubspec/lockfile差分なし。
- dart format --output=none --set-exit-if-changed lib test：67ファイル、変更なし。git diff --check成功。
- flutter analyze --no-pub：指摘なし。
- flutter test --no-pub --reporter expanded：全230件成功。ログ /private/tmp/os2604-c-priority-all-tests.log。
- 追加試験：v2/v3混在DB移行、年境界/対象外保持、全フィールド/設定保持、再open/順序/期間検索/中央値、失敗のロールバックと再試行。権限待ち30秒→許可→準備後の15秒、拒否/技術エラー、中断/再試行、前面復帰待ち、キャンセル後の遅い応答、計測中の離脱を合成入力/偽ネイティブ応答で検証。
- 初回テストはsandboxのlocalhostソケット制限で起動不可。昇格再実行で解決。権限チャネル試験のWidget仮想時刻との待ち合わせ失敗/停止は実イベントループの単体テストに直して解消。既存assertionの削除/skip/ダミー成功への変更なし。
- iOS Release（署名なし）：tool/flutter_with_xcode.sh build ios --release --no-codesign --no-pub 成功。Runner.app 60.2MB、Xcode build 27.0秒。pod install成功、Podfile.lock差分なし。ログ /private/tmp/os2604-c-priority-ios-build.log。実機へのインストールや端末DB変更は行っていない。
- ML KitのSPM非対応とApple Silicon Simulator向けarm64非対応の警告あり。実機向けビルドは成功。シミュレータでカメラ/AIの実機試験を代替しない。
- 差分と利用側を自己レビュー。以前のSTATEにある「os_2604でフェーズごとのCodexレビューはしない」というユーザー指示を引き継ぎ。

## 残課題・次の手順

1. 今回の版で初回カメラ許可/拒否/復帰と、旧秒形式記録を保持したアップデートを実機確認。アプリ/DB削除を自動実行しない。
2. B側の結果入力・撮影ナビゲーション修正の統合確認。古い入力を含む既存レポートの扱いも残る。
3. 過去比較のレポート接続と、十分な履歴を使う実機試験。
4. Swift Foundation Modelsブリッジと実機AI生成。現状AIは定型文切替のみ。通知配信/変更/拒否/タップ起動も実機未確認。
5. 最終版でオフラインデモ2回。rPPG/顔色特徴量/Android計測経路は後続。公開対応は別タスク。

## 環境

- SDK /private/tmp/os2604-c-flutter、PUB_CACHE=/private/tmp/os2604-c-dart/pub-cache、XDG_CONFIG_HOME=/private/tmp/os2604-c-config。
- CocoaPods /private/tmp/os2604-c-gems。GEM_HOME/GEM_PATH同ディレクトリ、RUBYOPT=-rlogger、binをPATHへ追加。tool/flutter_with_xcode.shでコマンド限定Xcode選択。システム設定は変更しない。
