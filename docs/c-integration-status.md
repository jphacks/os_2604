# CtoB2へのB側の接続状況

2026-10-17。ユーザーが共有したCtoB2.mdへの技術的な照合結果。Cへの送信は実施していない。

## B側で対応したこと

- Flutter 3.47.7 / Dart 3.13.5。
- camera 0.12.1、google_mlkit_face_detection 0.15.1、test 1.31.1を解決。camera_avfoundation 0.10.3+1、google_mlkit_commons 0.13.0はCの検証構成と一致。
- iOS最低15.5、カメラ利用目的、ML KitのCocoaPods組込を準備。Swift Package Manager非対応のML KitはCocoaPods併用。
- camera_avfoundation 0.10.3+1のCameraPlugin.swiftと作者のテストで、enableAudio=falseなら音声権限を要求しない分岐を確認。マイク利用目的は追加していない。C側はenableAudio:falseを維持する。
- SQLiteによる初回説明の確認状態の永続化と、実DB再open試験を実装。説明確認とカメラ権限許可は別に扱う。
- CのIDを再発行せず保存・更新する接続方針。Cの共有型をレビューして利用し、別の互換性のないモデルを新設しない。

## 新たにユーザーが決定した挙動

1. 中断・失敗は健康記録に保存しない。
2. 自己申告なしでも有効な計測結果を保存する。
3. 健康記録を個別・全件削除できる。
4. 今日を除く直近7暦日の有効記録3件以上から比較する。比較の数値をAIに作らせない。

自己申告の分析関数はBに実装済み。項目値が不足する場合は値を捏造せず、中央値をnullとする。健康記録DBと実際のC結果への接続はまだ未実装。

## コード取得待ち

最新取得時のorigin/cはf3ffa16で、frame_luminance.dartとframe_signal_quality.dartまで。CtoB2.mdにあるHealthCheckResult、HealthScanService、CameraScanService、ScanWidgetと56件のテストは未取得。

ユーザーがCへ本体のcommit・pushとコミットIDの共有を依頼する。取得後に実際の型・キャンセル・ライフサイクル・品質設定をレビューし、Bの撮影画面、即保存、結果・履歴・削除へ接続する。文章回答だけから本体取得・実機成功を推定しない。

レポート生成API、タイムアウト、再生成、正式対象iPhone 17 / iOS 27以降での実機試験は引き続き必要。Cの暫定閾値はC側の実装・承認報告として受領し、実機検証済みとは扱わない。
