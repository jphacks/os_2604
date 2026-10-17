# 現在の作業状態

## 2026-10-17 B-05 通知・B-06 デモ手順書（作業ブランチ）

- ブランチ：`add/20261017-add-local-notifications-and-demo-guide`（origin/main 955f1bb から。PR #4 はマージ済み）
- B-05 ローカル通知（実装済み・実機未確認）：
  - 設定画面（`lib/screens/settings_screen.dart`）に「毎朝の通知」スイッチ（初期オフ）と「通知時刻」タイル（HH:mm、時刻ピッカー、オフ中は無効）。オンでiOS許可を要求。拒否→オフのまま「通知が許可されていません。設定アプリから許可できます。」。登録失敗→「通知を設定できませんでした（設定は変更されていません）」
  - 時刻変更で再登録（固定ID1つ）、オフで取消。Driftに保存（schema v3、テーブル ReminderPreferences、マイグレーションはテーブル追加のみ）。アプリ起動時に保存済み設定を非ブロックで再登録
  - 通知：タイトル「15秒チェック」、本文「おはようございます。今日の記録をつけましょう。」、payloadなし、タップでアプリ起動
  - パッケージ：flutter_local_notifications ^22.3.2、timezone ^0.11.2、flutter_timezone ^5.1.1。ネイティブ：`ios/Runner/AppDelegate.swift`（UNUserNotificationCenter delegate）、Androidはdesugaring＋AndroidManifestのreceiver（Androidは正式対象外、inexact scheduling）
  - **`pod install` 未実行**（Macのディスク空きがほぼ無い）。次のiOSビルド前に必要。ネイティブは未コンパイル
- B-06 デモ手順書：`docs/demo-guide.md` を作成。**要確認**：ShiFtのReleaseビルド／devicectlの具体コマンド、カメラ許可ダイアログが出る時点、中断メッセージの文言（実装との一致）、履歴比較のデモ方法（当日の記録は基準値から除外されるため）、A-03（A担当のデモ手順・スクリーンショット）との分担
- 環境：Macのディスク空きが約1〜4GBしかなく、シミュレータ／実機ビルドができなかった
- 決定事項：Swift の Foundation Models ブリッジは分業書どおり C 担当。os_2604 ではフェーズごとの Codex レビューは行わない（ユーザー指示）
- Cの方針：AI出力は固定短文のキー選択のみ（自由文は捨てる）。Cが時計・進捗・キャンセルを所有。詳細は `docs/c-ai-integration.md`、`docs/c-integration.md`
- 参考（マージ済みの履歴・Cレポート接続）：HealthRecordRepository が ShiFt の HealthRecordStore 契約を実装。履歴は今日を除く直近7暦日・有効3件以上で基準値、不足時は「基準値蓄積中」。結果画面の「レポートを作成」で生成（タイムアウト10秒）。撮影後は insert 成功時のみ遷移、失敗計測は保存しない

## 検証

- B-05後：dart format OK、flutter test 217件成功、flutter analyze 指摘なし
- 実機未確認：通知の許可ダイアログ、設定時刻の配信、毎日の繰り返し、タップ起動、iOS/Androidネイティブコンパイル
- Swift ブリッジ未実装のため、現状のレポートは常に定型文（bridgeUnavailable）

## 実機確認（ShiFt、マージ前の統合版）

- iPhone 17 / iOS 27.0.1 をFlutterで検出。署名付きReleaseビルド成功（Runner.app 59.5MB）、devicectlでインストール・起動成功（com.example.os2604）
- ユーザーが実機で15秒計測 → 結果画面 → 再起動後の履歴保持まで確認。通常動線は確認済み
- 未確認（通常動線の成功から合格扱いにしない）：権限拒否・暗所・計測中の顔外れ・アプリ離脱・削除・機内モードの実機試験。Swift AIの実機動作も未確認

## 環境メモ

- SDK /private/tmp/os2604-c-flutter、PUB_CACHE=/private/tmp/os2604-c-dart/pub-cache、XDG_CONFIG_HOME=/private/tmp/os2604-c-config
- CocoaPods 1.16.2 は /private/tmp/os2604-c-gems。利用時は GEM_HOME/GEM_PATH を同ディレクトリ、RUBYOPT=-rlogger、bin を PATH に追加。システムRuby/Xcode選択は変更しない
- 署名は Git除外の ios/Flutter/LocalSigning.xcconfig。既存Word/PDF4文書は未追跡のままPR対象外

## 次

1. `pod install` → 実機ビルド（まずMacのディスク空きを確保）
2. 実機で T01〜T08 と通知配信（設定時刻に届く／タップ起動／時刻変更）を確認
3. Aと手順書（`docs/demo-guide.md`）の分担を確認（A-03）
4. C の Swift ブリッジ
