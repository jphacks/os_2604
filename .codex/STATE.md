# 現在の作業状態

## 2026-10-17 B⇔C統合（ブランチ B）

- ブランチ：作業は `B` に統合済み。main（Cの AI 準備、PR #2）も `B` にマージ済み。
- 目標：CのスキャンAPI（b6844e3）をBの画面基盤に接続し「開始→15秒→結果→即時保存→履歴」を通す
- 完了（コミット済み a12f5e8）：健康記録DB
  - `AppDatabase` に `HealthRecords` テーブル追加、schemaVersion 2（v1→v2は新テーブル作成のみ、オンボーディング保持）
  - `lib/services/db/health_record_repository.dart` の `HealthRecordRepository`：insert（重複IDは例外）、updateSelfCondition / updateTemperature / updateReport（モデル検証経由・存在しないIDは StateError）、findById、findInRange（from以上to未満・新しい順）、baselineObservations（history_baseline 入力）、watchAll、delete、deleteAll（健康記録のみ）
  - measuredAt・elapsed はマイクロ秒整数、enumは名前で保存
- 完了（コミット済み 6cf0ca8）：撮影画面・結果画面の配線
  - 撮影画面 `lib/screens/scan_screen.dart`（CameraScanService+ScanWidget）：成功時は insert 成功後にのみ結果画面へ遷移、保存失敗は再試行、失敗理由別メッセージ（保存なし）、戻る時 cancelScan、世代カウンタで古い結果を破棄
  - 結果画面 `lib/screens/result_screen.dart`：findById、未測定表示、体調・体温を同一IDに追記、レポートは未生成表示のみ
  - `MorningCheckApp` に repository と createScanSession を注入、ScanUnavailableScreen 削除、ホームの「未接続」文言削除
- 検証（このマージ後）：dart format OK、flutter test 168件成功、flutter analyze info 37件（C側ファイル由来、エラー・警告なし）
- 未検証：実機カメラ・権限。履歴・設定画面の途中実装は `feature/b-c-integration` の作業ツリーに未コミットで残っている（未検証）。

## C担当：AI利用可否・失敗時処理（main から取り込み）

- ブランチ：`c`（`origin/c` 追跡）。計測API一式は `b6844e3`、定型文部品は `b8a850e`。push・PR作成・マージは未依頼。
- 前提：全員iPhone 17 / iOS 27+ / Day 1開始とユーザー回答あり。正確なOS・実機動作は未確認。
- 合意：BがC側に合わせる旨の回答あり。Cが時計・進捗・キャンセルを所有し、Bが表示・保存・遷移を担当する。Day 1品質閾値も実機調整用としてユーザー承認済み。
- 実装：`lib/models/` に共通結果・計測契約。`lib/features/scan/` に設定、顔領域判定、単調時計の計測制御、iOS前面カメラ／ML Kit接続、CameraScanService、ScanWidget。生画像は処理中のメモリ内だけで扱い、永続化しない。古い非同期応答・顔外れ・観測途絶・ライフサイクル・技術エラーを失敗として処理。
- AI準備：`lib/services/ai/on_device_ai_client.dart`・`foundation_models_client.dart`・`on_device_ai_runner.dart` と対応する2テスト。利用可否の区分、ブリッジ欠落、例外・タイムアウト・不正応答の定型文、二重要求、キャンセル、破棄後の遅い応答を処理。定型文部品にモードを除いた本文の合成を追加。共有型・計測API・DB・pubspec・ios/は変更していない。
- AI出力方針：適用可能な固定短文のキーを一つ選ぶ方式。自由文・未知のキー・未入力項目への補足は捨てる。本文中の値はDartが既存記録から表示し、AIに創作させない。実際に選択が通った場合だけonDevice、失敗はtemplateと理由を返す。これはC内部の実行結果で、B/Cの共有HealthReport・比較・生成日時の契約は未確定。
- キャンセル：ローカル結果は直ちに定型文で完了。ネイティブキャンセルはbest effort。元のFutureが終わるまでbusyを維持し、キャンセル応答だけで新規生成を始めない。DBへの書き込みは持たず、削除・入力更新との競合制御はBが担当。
- テスト：`test/features/scan/` と `test/services/ai/`。偽のクライアント／MethodChannelと合成入力のみ。実画像や個人データなし。
- 文書：`docs/c-ai-integration.md`（使用例・ネイティブ通信案・Apple API確認・キャンセル条件・未確認事項）、`docs/c-integration.md` に入口を追加。
- C単体の検証：公式Flutter stable（3.47.7 / Dart 3.13.5）を `/private/tmp/os2604-c-flutter` に取得し、一時パッケージ `/private/tmp/os2604-c-flutter-check`、PUB_CACHE `/private/tmp/os2604-c-dart/pub-cache` で実施。camera 0.12.1、google_mlkit_face_detection 0.15.1、test 1.31.1（1.33.0はFlutter固定test_apiと競合のため検証用のみ変更）、fake_async 1.3.3、camera_platform_interface 2.15.0。analyze指摘なし、全121件成功（既存66＋AI実行管理30＋チャネル25）。追加依存なし。
- B返信受領：`/Users/shindenfuta/Downloads/b-to-c-integration-reply.md` を照合。B基盤は`B`の`fb6878b`、SDKはCと同じ、パッケージ名`os_2604`。B基盤はmain/Bへの統合で取込済み。
- 統合時の照合：B提案は保存用IDをBが発行し共有型をBが取りまとめる。C実装は結果ID発行・共通型作成済み。Cの既存型を起点にBがレビューし、結果IDをそのまま保存する回答案を接続メモへ記載。Bでの採用確認はまだない。B返信の未承認の比較条件・削除範囲・失敗履歴案は確定仕様に取り込まない。
- 未確認：Swiftブリッジ未実装のため実機AIは未接続。Xcode 27.0のSDKとApple公式資料でLanguageModelError等の名前を照合したが、Swiftコンパイル・モデル実行は未確認。CocoaPodsはPATHにない。実機撮影・品質調整・DBまでの通し試験も未実施。
- 未決事項：中断履歴・比較条件・削除範囲。
- 次：Bとの共有レポートAPI・タイムアウト秒数（Dartでは必須引数で既定値なし）を確定し、AI接続メモのチャネル登録をBのネイティブ変更窓口と調整。P0統合・実機確認を優先し、その後にApple Intelligence設定・モデル準備・生成・オフライン・保存後の追記を確認する。

## 次（統合後）

- 結果画面へのレポート接続（Cの on_device_ai_runner / template_record_summary を使用、共有レポートAPI・タイムアウト秒数は B/C で確定が必要）、履歴画面・設定画面の削除の完成、ホームの本日状態・前回結果、実機での通し確認。
