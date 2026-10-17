# 現在の作業状態

## 2026-10-17 Swift Foundation Models ブリッジ実装・過去比較のレポート本文接続・実機更新

- 作業ブランチ：`manual_ui_testing_migration`（`/Users/shindenfuta/JPHACKS` の `c` `e2d04a6` を fast-forward 取込した上で実装）。
- 実装内容：
  1. **過去比較のレポート本文接続**：`ResultScreen._generateReport` で記録日基準の直近7暦日（当日を除く）の有効記録から `calculateHistoryBaseline` を算出し、`OnDeviceAiRunner.generateReflection(scan, baseline: baseline)` と `TemplateRecordSummary` へ接続。履歴不足時は「過去比較：基準値蓄積中（有効記録 X/3件 または 体調の記録 X/3件）」、有効記録3件以上かつ体調入力3件以上では「過去比較：直近7日間（今日を除く）の体調の中央値 ...」をレポート本文（端末内AI・定型文とも）に表示。基準値成立時はAI短文選択キー `reviewHistoryComparison` も許可。
  2. **Swift 側の Foundation Models ブリッジ実装**：`ios/Runner/AppDelegate.swift` に `jp.jphacks.os_2604/on_device_ai` チャネルと `OnDeviceAiBridge` を実装。`SystemLanguageModel.default.availability`・日本語ロケール対応確認、`LanguageModelSession` による短文キー生成、requestId 単位の `Task` 管理・キャンセル・単発完了保証（`PendingGeneration`）、iOS 26 `GenerationError` / iOS 27 `LanguageModelError`・`SystemLanguageModel.Error` のエラーコード変換を接続。
- 自動検証：`dart format --output=none --set-exit-if-changed lib test` は69ファイル変更なし、`flutter analyze --no-pub` 指摘なし、`flutter test --no-pub --reporter expanded` 全257件成功（既存252件＋過去比較レポート単体・Widgetテスト5件）。
- ビルドと実機導入（physical iPhone 17 / iOS 27.0.1、`00008150-000268A03EC2401C`）：
  1. 本体アプリ（`com.example.os2604`）：署名なしReleaseビルド（60.3MB）および署名付きReleaseビルド（`build/ios/iphoneos/Runner.app` 60.8MB）成功。既存データを消さずに `devicectl device install app` で上書き導入し、`devicectl device process launch` で起動成功。
  2. 初回許可ダイアログ確認用アプリ（`com.example.os2604.permissioncheck`、表示名「15秒チェック 権限試験」）：実機に導入済み。
- DB移行（schema v4）の実機扱い：更新前の実機履歴が空であったため、実測履歴にダミーデータを混在させない原則に従い、既存記録を保持した schema v4 日時移行は自動テスト（`legacy_timestamp_migration_test.dart`）での検証結果と区別して記録。
- 実機手動UI確認（physical iPhone 17 / iOS 27.0.1）：ユーザーから「1. 実機での手動UI確認が完了しました」と報告を受領（① `com.example.os2604.permissioncheck` での初回カメラ許可ダイアログ確認、② `com.example.os2604` でのオンデバイスAI／定型文フォールバック・過去比較レポート表示、③ 撮影中断・体調/体温入力解除と保存・履歴・削除・通知設定、④ オフラインデモ確認）。翌日の通知繰り返しは当日外のため未確認として区別。
- 次：変更のコミット・PR・ブランチ統合（`origin/main` / `origin/codex/b-camera-tab-ui` 等との照合）。

## 以下は e2d04a6 時点の記録

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
