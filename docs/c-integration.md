# C担当：計測APIとBへの組み込み手順

## 合意と現在地

2026-10-17、ユーザーから「BがC側に合わせてよいと回答した」と共有されたため、Cが15秒の時計・進捗・キャンセルを持つ契約で実装した。全員iPhone 17 / iOS 27以降、Day 1開始。品質閾値もユーザーが実機調整用の暫定値として承認済み。

共通型、単調時計による計測制御、iOS前面カメラ→ML Kit→顔領域の輝度・角度・位置・動き判定、ScanWidgetを実装。B管理のFlutter骨格・pubspec・main.dart・ios/は変更していない。AI・DB・アプリ全体の動線は未接続。実機の撮影、閾値の妥当性、AI対応は未検証。

### Bの返信との照合

ユーザー共有の `b-to-c-integration-reply.md`（2026-10-17）では、B基盤はブランチ`B`・コミット`fb6878b`で作成済み、Flutter 3.47.7 / Dart 3.13.5、パッケージ名`os_2604`と報告されている。現在のCチェックアウトには未取込で、当該コミットもローカルにない。Bのビルド・起動結果はB側の報告として扱い、C統合やiPhone 17での確認結果へ読み替えない。

返信自体は未合意段階の提案を含む。先ほどのユーザーによるC案での進行承認・暫定閾値承認とは分けて扱う。自動マージやコード変更の指示としては扱わない。

- 時計、準備中の待機、成功／失敗の分離、技術エラー、キャンセル、古い応答の破棄はB案と整合する。
- **IDの発行元は最終照合が必要**：B案は初回保存前にBが発行、C実装は`HealthCheckResult.id`をCが発行する。内部のセッション世代とは分離済み。現状のC結果IDをBがそのまま保存すれば、再発行せず同一IDで追記できる。これはCからの回答案であり、B側での採用確認はまだない。
- **共有型の取りまとめは最終照合が必要**：B返信はBが取りまとめる案、Cにはユーザーの先行承認に基づく実装がある。既存の`lib/models/`を一組の起点としてBにレビューしてもらい、別の互換性のない型を追加しない。
- 集計をB、説明文・定型文をCが担当するB案は、比較ロジックを重複させない接続案として整合する。レポート入力型・タイムアウト・再生成は未確定、未実装。
- 失敗履歴、比較の具体条件、削除範囲は未決のまま。返信の「直近7日・3件」等を確定仕様へ取り込んでいない。
- 依存・ネイティブ設定はB窓口を維持。Cで解決したテスト依存は下記のとおりで、`test: 1.33.0`の競合は1.31.1で解消済み。

## Bが使うAPI

- `lib/models/scan_contract.dart`：`HealthScanService`、`ScanOutcome`、`ScanProgress`。
- `lib/models/health_check_result.dart`：保存する共通の `HealthCheckResult`。
- `lib/features/scan/camera_scan_service.dart`：実カメラ用 `CameraScanService`。
- `lib/features/scan/scan_widget.dart`：プレビューとライフサイクル中断を扱う `ScanWidget`。

```dart
final scan = CameraScanService(); // 承認済みのDay 1検証設定を使用

// 撮影画面のプレビュー。A/Bの顔ガイドはoverlayに重ねる。
ScanWidget(
  service: scan,
  preview: scan.preview,
  placeholder: const Text('カメラを準備しています'),
  overlay: faceGuide,
);

// Bの開始ボタンで呼ぶ。結果は未保存なのでBが即時保存する。
final outcome = await scan.startHealthScan();
switch (outcome) {
  case ScanSuccess(:final result):
    await repository.insert(result); // BのDB APIへ置換。失敗なら保存成功と表示しない。
    // 保存後に自己申告の追記、レポート生成、結果画面への遷移を行う。
  case ScanFailure(:final reason, :final elapsed):
    // Bが失敗理由と再試行を表示する。成功記録として保存しない。
}

// 進捗表示はscan.progress。StreamBuilderのinitialDataはscan.currentProgress。
// UI用の別タイマーで終了判定しない。
// 画面を覆う別ルートへの遷移前にもBが明示的にキャンセルする。
await scan.cancelScan();
// 撮影画面を取り除いた後、所有者がサービスを解放する。
await scan.dispose();
```

上記の `faceGuide` と `repository` はB側のUI・保存処理を示す例であり、Cが実装したオブジェクトではない。レポート生成APIはP1で接続する。

### 計測と結果

- `startHealthScan()` はカメラを初期化し、顔位置・品質の準備が連続して満たされた後に15秒を開始する。準備時間は計測に含めない。
- `ScanProgress.phase` は `idle / preparing / measuring / completed / failed`。準備中の修正案内は `guidance`。失敗理由は `failureReason`。
- 時間はCの単調時計が所有。壁時計の日時は計測開始時の `measuredAt` にだけ使う。
- `durationSec` は目標の15秒、`elapsed` は有効な終端フレームまでの実観測時間。DBには実経過時間も残す。フレーム受信時刻はDart側で、非同期の顔検出より前に採る。
- 15秒経過だけでは成功しない。終端まで連続した観測と、有効な終端フレームが必要。フレーム途絶、推論遅延、顔外れ、品質低下は失敗になる。
- `ScanSuccess.result` はID・日時・実経過・`faceDetected: true`・`quality: good`を含む。心拍・顔色特徴量・体温・自己申告・レポートは未取得のため `null`。`aiMode` も生成前は `null`。
- 体温・心拍の値を後で記録する場合は、対応する出典も必須。自己申告は1〜5。レポート本文と実際の生成モードは同時に設定する。
- `ScanFailure` は理由と実経過時間を返す。計測前なら実経過は0。中断記録を履歴へ保存するかは未決のため、成功用の結果を作らない。

### 失敗と後片付け

| 状態 | 返す値・B側の対応 |
| --- | --- |
| 計測前の顔未検出・光量不足 | 準備中の `guidance`。位置・明るさの調整案内 |
| 権限拒否・制限 | `permissionDenied`。説明と設定への案内 |
| 計測途中の顔外れ | `faceNotFound` の失敗。記録を無効として再試行 |
| 光量・角度・動き・複数顔・欠損・観測途絶 | `poorQuality` の失敗 |
| ユーザーキャンセル・アプリ離脱 | `interrupted` の失敗 |
| カメラなし・初期化異常 | `cameraUnavailable` |
| 検出処理・バッファ・ストリーム・解放の異常 | `processingFailed` |

測定成功・失敗・キャンセル時にカメラと検出器を解放し、終端結果を返す。再試行ではセッション世代を変え、古い検出応答を無視する。二重開始・破棄済みサービスの使用はプログラムの誤用として `StateError`。ボタンは処理中に無効化する。

初期化と後片付けには各10秒の技術的タイムアウトがある。解放に失敗したサービスはカメラ再使用の安全を確認できないため再起動しない。`dispose()` 後、新しい `CameraScanService` を作る。

ScanWidgetはアプリがforegroundを離れた時、取り外された時、サービスが差し替わった時にキャンセルする。復帰時に計測を自動再開しない。別ルートで覆うだけではWidgetが取り外されない場合があるため、その遷移前の `cancelScan()` はBが呼ぶ。

## 承認済みのDay 1暫定設定

`ScanConfiguration.day1Trial()` に実装した。実機での調整用であり、健康指標の精度や完成版の閾値として検証された値ではない。

| 項目 | 暫定値 |
| --- | --- |
| 顔領域の輝度 | 50以上（0〜255） |
| 上下 / 左右 / 傾き | 絶対値で15° / 20° / 10°以内 |
| 顔中心の位置 | 画面中央から幅・高さの各20%以内 |
| 顔の幅 | バッファ幅の20〜80% |
| 連続フレーム間の顔中心の移動 | 幅・高さの各5%以内 |
| 準備安定時間 | 500ms |
| 観測途絶・推論遅延 | 500ms以上で計測無効。準備中は安定期間をリセット |

BGRAの顔領域のみを集計する。画面背景だけが明るくても合格させない。iOSカメラは縦向きのフレームに固定する。採用版のcamera_avfoundationとML Kit Commonsのネイティブ実装を照合し、検出矩形と生バッファを同じ座標系で扱う。ML Kitには角度取得のためaccurateモードを使い、取得できない角度を0で代用しない。

## Bへ渡す依存・ネイティブ設定

Cのコードだけではアプリを起動できない。Bのアプリ骨格へ以下を反映する。Cから外部メッセージは送信していない。

| 対象 | 必要な対応・今回確認した構成 |
| --- | --- |
| Flutter | 一時検証はFlutter 3.47.7 / Dart 3.13.5。BのSDKでも依存解決を確認 |
| 本体依存 | `camera: 0.12.1`、`google_mlkit_face_detection: 0.15.1` |
| テスト依存 | `flutter_test`（SDK）、`test: 1.31.1`、`fake_async: 1.3.3`、`camera_platform_interface: 2.15.0` |
| iOS | カメラ利用目的、Deployment Target、ML Kitのビルド条件を反映 |
| 音声 | `enableAudio: false`。録画・静止画保存APIは呼ばない。マイク権限の要否はBが採用版のネイティブ設定と照合 |
| 撮影UI | A/Bの顔ガイド・開始/再試行・進捗・失敗表示・設定案内を接続 |
| 保存 | `ScanSuccess`を直ちに保存。同一IDへ後から任意入力・レポートを追記 |

このFlutter版のflutter_testはtest_apiを固定しているため、`test: 1.33.0`とは競合した。1.31.1で解決済み。camera_avfoundationは0.10.3+1、google_mlkit_commonsは0.13.0に解決された。依存をむやみに最新版へ上げず、BのSDKに合わせてlockfileを固定する。

## 検証と未確認

一時Flutterプロジェクト `/private/tmp/os2604-c-flutter-check` に同じlib・testをコピーして検証。Flutter SDKは `/private/tmp/os2604-c-flutter`、PUB_CACHEは `/private/tmp/os2604-c-dart/pub-cache`。ルートにpubspecは作成していない。

```sh
# リポジトリルート：整形確認
/path/to/flutter/bin/dart format --output=none --set-exit-if-changed lib test
# 上記依存を設定し、lib・testをコピーしたFlutterプロジェクト内
flutter pub get
flutter analyze
flutter test --reporter expanded
```

テストは合成バッファ・合成角度・偽のカメラプラットフォーム・ML Kit応答を使用する。準備時間の除外、15秒終端、顔外れ、光量、欠損、観測途絶、権限拒否、初期化、解放、キャンセル、再試行時の古い応答、ライフサイクルを確認する。実画像・個人の測定値は含まない。

2026-10-17の最終結果：一時Flutter環境の `flutter analyze --no-pub` は指摘なし、`flutter test --no-pub --reporter expanded` は56件成功。リポジトリの整形・差分チェックも成功。

実機の撮影・性能、縦向きプレビューと顔位置、権限ダイアログ、BのDB保存・履歴までの動線は未確認。ローカル環境にはXcode 27.0があるがCocoaPodsはPATHにない。iOSアプリのビルドはまだ行っていない。AndroidとWebは実装保証しない。

## 次の統合

1. BがFlutter骨格・依存・iOS設定へ反映し、撮影画面に上記APIを接続。
2. iPhone 17で通常、暗所、顔外れ、アプリ離脱、再試行、権限拒否を確認し、暫定閾値を調整。
3. Bと「開始→15秒→結果→即時保存→履歴」を確認。
4. P1の定型レポートとFoundation Modelsを接続。比較期間・最低履歴件数・削除範囲は引き続き人間が決める。P2はP0完了後。

## 参照した一次資料

- [camera（Flutter公式）](https://pub.dev/packages/camera)：APIとライフサイクル・権限処理。
- [google_mlkit_face_detection（作者）](https://pub.dev/packages/google_mlkit_face_detection)：iOS 15.5以降などの条件と、顔枠・角度のAPI。Googleによる保守ではない。
- [作者のカメラ接続例](https://github.com/flutter-ml/google_ml_kit_flutter/blob/master/packages/example/lib/vision_detector_views/camera_view.dart)：入力画像のメタデータとプラットフォーム別の変換。
- [Apple：Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)：P1の利用可否確認とフォールバック。今回は未実装。

資料確認と一時Flutter環境でのテストは、iPhone実機での動作保証を意味しない。
