# 現在の作業状態

## 2026-10-17 c：B/C統合と実機導入（手動確認待ち）

- ユーザー合意：B/C統合確認→統合版の実機試験の順で進め、実機へのインストール・確認と `STATE.md` 更新・コミットを行う。
- ブランチ `c` の `5e4d125`（Cの日時移行・権限待ち修正）へ、B修正がPR #6で取り込まれた `origin/main` `5d591c5` をマージし、Cの権限待ちキャンセル処理とBの画面解放処理（`ScanScreen._release`）の結合テスト `test/screens/scan_permission_flow_test.dart` を追加してコミット。`main` 自体は変更しない。
- 実装ファイルは自動マージ成功。`STATE.md` だけ競合したため、この現在地と下記のC側記録を保持して解消。Bの結果表示更新・入力解除・古いレポート消去・保存競合防止と撮影画面の戻る/保存/キャンセル修正を含む。
- 統合後の自動検証：`dart format --output=none --set-exit-if-changed lib test` は69ファイル変更なし、`git diff --check` 成功、`flutter analyze --no-pub` 指摘なし、`flutter test --no-pub --reporter expanded` 全252件成功（権限待ち中の `inactive` 待機からの「戻る」離脱、権限拒否後の再試行→許可を含む。ログ `/private/tmp/os2604-bc-integrated-tests.log`）。
- ビルドと実機導入（physical iPhone 17 / iOS 27.0.1、`00008150-000268A03EC2401C`）：
  1. 本体アプリ（`com.example.os2604`）：署名付きiOS Releaseビルド成功（`build/ios/iphoneos/Runner.app` 60.7MB、`/private/tmp/os2604-bc-integrated-build.log`）。ロック解除と更新前の空履歴をユーザー確認済みのため、データを消さずに `xcrun devicectl` で上書きインストール・プロセス起動成功。旧記録がないため、既存記録を保持したDB移行（schema v4）は今回は自動テストの結果と区別して扱う。
  2. 初回許可ダイアログ確認用アプリ（`com.example.os2604.permissioncheck`、表示名「15秒チェック 権限試験」）：既存アプリの権限をリセットせず初回OS許可ダイアログを確認できるよう、一時コピー `/private/tmp/os2604-bc-permissioncheck-62oxv4fl` で別Bundle IDの署名付きReleaseビルド成功（`/private/tmp/os2604-bc-permissioncheck-build.log`）、実機へ `xcrun devicectl` でインストール・プロセス起動成功。
- B側237テスト成功・iPhone 15へのインストール報告はBの記録として区別して保持。実機の画面操作はユーザー手動試験で行い、プロセス起動成功だけで手動試験合格と扱わない。
- 次：実機での手動確認（`com.example.os2604.permissioncheck` での初回カメラ許可ダイアログ表示・待機・許可後の計測開始、および上書き更新した `com.example.os2604` での撮影中断・結果入力解除・保存・履歴・通知設定）。

## 以下は5e4d125に含めた修正記録

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
