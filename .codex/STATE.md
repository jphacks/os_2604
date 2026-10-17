# 現在の作業状態

## 2026-10-17 B/C統合・履歴・Cレポート接続（作業ブランチ）

- ブランチ：`add/20261017-add-history-and-connect-c-report`（origin/main f574c65 を取り込むマージ中。PR作成前）
- 統合の結論（PR #3 で blocker だった保存契約の食い違いは解消済み）：
  - ShiFt の `HealthRecordStore` 契約を、こちらの `HealthRecordRepository` が実装する。measuredAt・elapsed はマイクロ秒整数のまま維持
  - `DriftHealthRecordStore` は薄いサブクラスとして復元
  - 履歴画面は ShiFt 版を採用（ユーザー決定）し、基準値サマリーを追加。品質表示は記録の実値（良好／不十分／中断）
  - ShiFt のテストを移植（bc_integration_test は「レポートを作成」ボタン方式に合わせて調整）
  - main 側のコンパイルエラー14件は今回のマージで解消
- B：履歴（新しい順・未測定表示・結果画面へ遷移・確認付き個別削除、今日を除く直近7暦日・有効3件以上の基準値、不足時は「基準値蓄積中」）、設定（確認付き全件削除、オンボーディング保持、通知は未実装表示）、ホーム（本日の実施状態・前回結果）
- Cレポート接続：main.dart で OnDeviceAiRunner（FoundationModelsClient、タイムアウト10秒＝ユーザー決定）を1つ生成し結果画面へ注入。結果画面の「レポートを作成」ボタンで生成（ユーザー決定）。updateReport で同一IDへ追記。生成世代ガード（入力保存・離脱・削除時は遅い応答を書かない）。モード表示（端末内AI／定型文）。フォールバック理由はDBに保存しない
- 基盤：schemaVersion 2。撮影後は insert 成功時のみ結果画面へ遷移、保存失敗は同じIDで再試行。失敗計測は履歴に保存しない
- 決定事項：Swift の Foundation Models ブリッジは分業書どおり C 担当。os_2604 ではフェーズごとの Codex レビューは行わない（ユーザー指示）
- Cの方針：AI出力は固定短文のキー選択のみ（自由文は捨てる）。Cが時計・進捗・キャンセルを所有。詳細は `docs/c-ai-integration.md`、`docs/c-integration.md`

## 検証

- flutter test 200件成功、flutter analyze 指摘なし、dart format 変更なし
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

1. PR → main（マージは人間が行う）
2. 実機で未確認項目の試験
3. 通知（P1）
4. C の Swift ブリッジ
