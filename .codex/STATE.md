# 現在の作業状態

## 2026-10-17 C担当：AI利用可否・失敗時処理の準備

- ブランチ：ユーザー指定の `c`、`origin/c`を追跡。計測API一式は `b6844e3` でpush済み。定型文部品は `b8a850e` でcommit済み、未push。今回のAI準備コード・テスト・接続メモ・本状態ファイルをユーザー依頼でコミットする。push・PR作成・マージは未依頼。
- 前提：全員iPhone 17 / iOS 27+ / Day 1開始とユーザー回答あり。正確なOS・実機動作は未確認。
- 合意：ユーザーからBがC側に合わせる旨の回答を共有。Cが時計・進捗・キャンセルを所有し、Bが表示・保存・遷移を担当する。Day 1品質閾値も実機調整用としてユーザー承認済み。
- 実装：`lib/models/` に共通結果・計測契約。`lib/features/scan/` に設定、顔領域判定、単調時計の計測制御、iOS前面カメラ／ML Kit接続、CameraScanService、ScanWidget。生画像は処理中のメモリ内だけで扱い、永続化しない。古い非同期応答・顔外れ・観測途絶・ライフサイクル・技術エラーを失敗として処理。
- 今回の追加：`lib/services/ai/on_device_ai_client.dart`・`foundation_models_client.dart`・`on_device_ai_runner.dart` と対応する2テスト。利用可否の区分、ブリッジ欠落、例外・タイムアウト・不正応答の定型文、二重要求、キャンセル、破棄後の遅い応答を処理。定型文部品にモードを除いた本文の合成を追加。共有型・計測API・DB・pubspec・ios/は変更していない。
- AI出力：準備段階では適用可能な固定短文のキーを一つ選ぶ方式。自由文・未知のキー・未入力項目への補足は捨てる。本文中の値はDartが既存記録から表示し、AIに創作させない。実際に選択が通った場合だけonDevice、失敗はtemplateと理由を返す。これはC内部の実行結果で、B/Cの共有HealthReport・比較・生成日時の契約は未確定。
- キャンセル：ローカル結果は直ちに定型文で完了。ネイティブキャンセルはbest effort。元のFutureが終わるまでbusyを維持し、キャンセル応答だけで新規生成を始めない。DBへの書き込みは持たず、削除・入力更新との競合制御はBが担当。
- テスト：`test/features/scan/` と `test/services/ai/`。今回分は偽のクライアント／MethodChannelと合成入力のみ。実画像や個人データなし。
- 文書：`docs/c-ai-integration.md` に使用例・ネイティブ通信案・Apple API確認・キャンセル条件・未確認事項を追加。`docs/c-integration.md` に入口を追加。
- 検証環境：公式Flutter stableを `/private/tmp/os2604-c-flutter` に取得（Flutter 3.47.7 / Dart 3.13.5）。一時パッケージは `/private/tmp/os2604-c-flutter-check`、PUB_CACHEは `/private/tmp/os2604-c-dart/pub-cache`。camera 0.12.1、google_mlkit_face_detection 0.15.1、flutter_test、test 1.31.1、fake_async 1.3.3、camera_platform_interface 2.15.0で依存解決。test 1.33.0はFlutter固定test_apiと競合したため検証用のみ1.31.1へ変更。
- 最終検証：一時Flutter環境の `flutter analyze --no-pub` は指摘なし、`flutter test --no-pub --reporter expanded` は全121件成功（既存66＋AI実行管理30＋チャネル25）。整形・差分チェックと検証コピーの一致も確認済み。追加依存なし。
- B返信受領：ユーザー共有の `/Users/shindenfuta/Downloads/b-to-c-integration-reply.md` を照合。B基盤は`B`の`fb6878b`で作成済み、SDKはCと同じ、パッケージ名`os_2604`との報告。Cへ未取込。返信の共有時は内容の照合・文書更新のみで、コード変更・fetch・merge・外部送信はしていない。
- 統合時の照合：B提案は保存用IDをBが発行し共有型をBが取りまとめる。C実装は結果ID発行・共通型作成済み。Cの既存型を起点にBがレビューし、結果IDをそのまま保存する回答案を接続メモへ記載。Bでの採用確認はまだない。B返信の未承認の比較条件・削除範囲・失敗履歴案を確定仕様へ取り込まない。
- 未確認：B基盤・依存・iOS設定はCへ未取込／未編集。Swiftブリッジ未実装のため実機AIは未接続。Xcode 27.0のSDKとApple公式資料でLanguageModelError等の名前を照合したが、Swiftコンパイル・モデル実行は未確認。CocoaPodsはPATHにない。実機撮影・品質調整・DBまでの通し試験も未実施。
- 次：Bとの共有レポートAPI・タイムアウト秒数（Dartでは必須引数で既定値なし）を確定し、AI接続メモのチャネル登録をBのネイティブ変更窓口と調整。P0統合・実機確認を優先し、その後にApple Intelligence設定・モデル準備・生成・オフライン・保存後の追記を確認する。中断履歴・比較条件・削除範囲は引き続き未決。
