# C担当：計測APIとBへの接続

2026-10-18更新。対象ブランチと実機確認の範囲は[B・C接続状況](c-integration-status.md)、制約・最終確認票は[C検証メモ](c-validation.md)を参照。初期の「本体取得待ち」「AI・DB未接続」は解消済み。

## 責任とAPI

| ファイル | 責務 |
| --- | --- |
| `lib/models/scan_contract.dart` | `HealthScanService`、`ScanOutcome`、`ScanProgress` |
| `lib/models/health_check_result.dart` | B・C共通の保存用 `HealthCheckResult` |
| `lib/features/scan/camera_scan_service.dart` | iOS実カメラ、品質設定、サービス生成 |
| `lib/features/scan/health_scan_controller.dart` | 単調時計、15秒判定、結果ID、成功／失敗、セッション世代 |
| `lib/features/scan/scan_widget.dart` | プレビュー、ライフサイクル中断 |
| `lib/screens/scan_screen.dart` | B側の即時保存・結果遷移・保存失敗表示 |
| `lib/screens/result_screen.dart` | B側の追記・過去比較・レポート生成／保存 |

`startHealthScan()` の `ScanSuccess.result` は未保存。Bは同じIDでDB insertを完了させてから結果表示・AI生成へ進む。`ScanFailure` は理由と実経過を返し、履歴に保存しない。UI用の独立タイマーで成功判定しない。

`ScanProgress.phase` は `idle / requestingPermission / preparing / measuring / completed / failed`。進捗ストリームの初期表示は `currentProgress`。`CameraScanService.preview` を `ScanWidget` に渡す。

## 通常／研究の切替

撮影画面の開始前に「研究モード」をオンにする。画面を開くたび通常へ戻り、開始後・再試行中・保存中は切り替えられない。切替時は旧サービスを解放し、通常は `day1Trial()`、研究は `day1Experimental()` のサービスを新規生成する。モードの選択は設定として永続化せず、各結果の `scanMode` を永続化する。

DBはschema v5。既存記録は `legacyUnknown`（モード未記録）として保持し、日時や既存推定値・本文を推測で書き換えない。通常・研究とも体調の過去比較の対象条件は従来と同じ。比較は自己申告の中央値で、実験心拍の良否判定はしない。

## 時間・許可・後片付け

- iOS独自チャネル `jp.jphacks.os_2604/camera_permission` の `requestCameraPermission` を `AppDelegate.swift` に登録済み。許可と前面復帰を確認してカメラを初期化する。
- OS許可待ちと顔位置確認は15秒に含めない。許可待ちの `inactive` は待機、`hidden / paused / detached` や画面離脱は中断。計測中の `inactive` も中断する。
- `durationSec` は目標15秒、`elapsed` は有効終端フレームまでの実観測時間。受信時刻は非同期顔検出より前に採る。時間経過だけで成功にせず終端の品質・観測継続を確認する。
- 初期化と後片付けは各10秒上限。OS許可回答待ちにこの期限を適用しない。
- 終端・取消でカメラ、検出器、タイマーを解放し古い応答を破棄。解放失敗後は同じサービスを再利用しない。
- 別ルートで撮影画面を覆う前に所有者が `cancelScan()` を呼ぶ。取り外し・差替え・背景化は `ScanWidget` も取消。所有者は最終的に `dispose()` を呼ぶ。復帰時に自動再開しない。

## 結果・失敗

成功はID・日時・実経過・`faceDetected: true`・`quality: good`を返す。通常モードでは心拍・顔色は `null`。研究モードでは実験評価の合格時だけ値を設定し、心拍出典は `rppgExperimental`。計測モードを結果とDBに保存する。取得できない値を0で補わない。体温・自己申告・レポート・生成モードは追記前には `null`。

| 状態 | APIと表示 |
| --- | --- |
| 開始前の顔未検出・光量不足 | 準備中の `guidance`、開始しない |
| カメラ権限拒否・制限 | `permissionDenied`、説明と設定案内 |
| 計測中の顔外れ | `faceNotFound`、無効と再試行 |
| 光量・角度・動き・複数顔・欠損・観測途絶 | `poorQuality` |
| 取消・アプリ離脱 | `interrupted` |
| カメラなし・初期化異常・許可チャネル不正 | `cameraUnavailable` |
| 検出・バッファ・ストリーム・解放異常 | `processingFailed` |

失敗結果画面や失敗履歴は追加しない。AI利用不可は計測失敗と区別し、有効記録を保存したまま定型文へ切替。[AI接続メモ](c-ai-integration.md)を参照。

## 承認済みのDay 1暫定設定

`ScanConfiguration.day1Trial()` の設定。実機調整用の暫定値で、心拍精度の保証ではない。

| 項目 | 暫定値 |
| --- | --- |
| 顔領域の輝度 | 50以上（0〜255） |
| 上下／左右／傾き | 絶対値15°／20°／10°以内 |
| 顔中心 | 中央から幅・高さの各20%以内 |
| 顔の幅 | バッファ幅の20〜80% |
| 連続フレームの顔中心移動 | 幅・高さの各5%以内 |
| 準備安定時間 | 500ms |
| 観測途絶・推論遅延 | 500ms以上で無効。準備中は安定期間リセット |

顔領域のBGRAから輝度を集計し、背景だけが明るい状態を合格にしない。縦向き、ML Kit accurateモード、欠けた角度を0で代用しない。心拍ブランチの追加設定は[C検証メモ](c-validation.md)に記載。

## 環境・検証

Flutter 3.47.7 / Dart 3.13.5。`camera 0.12.1`、`camera_avfoundation 0.10.3+1`、`google_mlkit_face_detection 0.15.1`、`google_mlkit_commons 0.13.0`。ML KitはCocoaPods併用。`enableAudio: false`、マイク用途文は追加していない。録画・静止画保存APIを呼ばない。依存やネイティブ設定の変更窓口はB。

ルートでREADMEの整形確認・解析・全テストを実行。一時Flutterプロジェクトへのコピーは不要。自動テストは合成バッファ・偽カメラ・ML Kit応答を用い、実画像・個人の測定値は含めない。シミュレータや自動テストをカメラ・AIの実機確認の代替にしない。

対象はiPhone 17 / iOS 27以降、確認記録があるOSは27.0.1。Android / Webの計測・Android AIは動作保証しない。他のOSバージョンを一括して検証済みとしない。

## 参照資料

- [camera](https://pub.dev/packages/camera)
- [google_mlkit_face_detection](https://pub.dev/packages/google_mlkit_face_detection)
- [Flutterのライフサイクル](https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html)
- [Appleのカメラ許可要求](https://developer.apple.com/documentation/avfoundation/avcapturedevice/requestaccess(for:completionhandler:))
