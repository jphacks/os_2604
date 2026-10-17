# 現在の作業状態

## 2026-10-17 B：履歴・設定・ホーム・Cレポート接続（作業ブランチ）

- ブランチ：`add/20261017-add-history-and-connect-c-report`（origin/main f574c65 から作成、未push）
- コミット：f1ef905（Cレポート接続）、fab97a3（履歴・設定・ホーム）、f8202c1（統合マージ）
- 完了：
  - 履歴画面：watchAll、新しい順、未測定表示、結果画面へ遷移、確認付き個別削除。calculateHistoryBaseline による「今日を除く直近7暦日・有効3件以上」の比較、不足時は「基準値蓄積中」。時計は注入
  - 設定画面：確認付き全件削除（オンボーディング状態は保持）、通知設定は未実装と表示
  - ホーム：本日の実施状態・前回結果を表示。「履歴未接続」文言は削除
  - Cレポート接続：main.dart で OnDeviceAiRunner（FoundationModelsClient、タイムアウト10秒＝ユーザー決定）を1つ生成し結果画面へ注入。結果画面の「レポートを作成」ボタンで、入力後に生成（ユーザー決定）。updateReport で同一IDへ追記。生成世代ガード（入力保存・離脱・削除時は遅い応答を書かない）。モード表示（端末内AIで作成／定型文で作成）とフォールバック理由の文言。理由はDBに保存しないため、再表示時はモードのみ
  - ウィジェットテストは終了前にアンマウントし、Driftストリームのタイマーでハングしないようにした
- 検証：dart format OK、flutter test 189件成功、flutter analyze はC側ファイルの info 37件のみ（エラー・警告0）
- 未検証：実機（iPhone 17）でのカメラ・権限・通し動作。Swiftブリッジ未実装のため現状は常に定型文（bridgeUnavailable）
- 決定事項：Swift の Foundation Models ブリッジは分業書どおり C 担当。os_2604 ではフェーズごとの Codex レビューは行わない（ユーザー指示）
- 次：PR作成（ユーザー判断）、実機で T01〜T08 確認、通知（P1、T08）、CによるSwiftブリッジ実装後の結合確認

## B基盤（統合済み・参考）

- 健康記録DB：`HealthRecords`、schemaVersion 2、`HealthRecordRepository`（insert / updateSelfCondition / updateTemperature / updateReport / findById / findInRange / baselineObservations / watchAll / delete / deleteAll）。measuredAt・elapsed はマイクロ秒整数、enumは名前で保存
- 撮影画面 `lib/screens/scan_screen.dart`：insert 成功後にのみ結果画面へ遷移、保存失敗は再試行、戻る時 cancelScan
- 結果画面 `lib/screens/result_screen.dart`：未測定表示、体調・体温を同一IDに追記

## C担当：AI利用可否・失敗時処理（main から取り込み）

- ブランチ：`c`（`origin/c` 追跡）。計測API一式は `b6844e3`、定型文部品は `b8a850e`。
- 前提：全員iPhone 17 / iOS 27+ / Day 1開始とユーザー回答あり。正確なOS・実機動作は未確認。
- 合意：Cが時計・進捗・キャンセルを所有し、Bが表示・保存・遷移を担当する。Day 1品質閾値も実機調整用としてユーザー承認済み。
- 実装：`lib/models/` に共通結果・計測契約。`lib/features/scan/` に設定、顔領域判定、単調時計の計測制御、iOS前面カメラ／ML Kit接続、CameraScanService、ScanWidget。生画像は処理中のメモリ内だけで扱い、永続化しない。
- AI準備：`lib/services/ai/on_device_ai_client.dart`・`foundation_models_client.dart`・`on_device_ai_runner.dart`。利用可否の区分、ブリッジ欠落、例外・タイムアウト・不正応答の定型文、二重要求、キャンセル、破棄後の遅い応答を処理。
- AI出力方針：適用可能な固定短文のキーを一つ選ぶ方式。自由文・未知のキー・未入力項目への補足は捨てる。本文中の値はDartが既存記録から表示し、AIに創作させない。実際に選択が通った場合だけonDevice、失敗はtemplateと理由を返す。
- キャンセル：ローカル結果は直ちに定型文で完了。ネイティブキャンセルはbest effort。元のFutureが終わるまでbusyを維持。DB書き込みは持たず、削除・入力更新との競合制御はBが担当（上記の生成世代ガードで対応済み）。
- 文書：`docs/c-ai-integration.md`、`docs/c-integration.md`。
- C単体の検証：公式Flutter stable（3.47.7 / Dart 3.13.5）で analyze指摘なし、全121件成功。
- 未確認：Swiftブリッジ未実装のため実機AIは未接続。Swiftコンパイル・モデル実行は未確認。CocoaPodsはPATHにない。実機撮影・品質調整・DBまでの通し試験も未実施。
- 未決事項：中断履歴・比較条件・削除範囲（B返信の未承認案は確定仕様に取り込まない）。
