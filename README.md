# 15秒健康チェック

毎朝、顔位置確認後に15秒撮影し、端末内に記録を残すFlutterの検証用MVPです。診断を目的としません。

## BとCの統合

作業ブランチ `codex/bc-device-check` で、mainのC計測APIとB基盤 `253a359` を接続しています。mainへの反映やpushは別途行います。

- 初回説明の確認状態をSQLiteへ保存し、次回起動時はホームへ進みます。
- ホームから撮影を開始し、顔位置・明るさ・向き・安定性を確認した後にCの時計で15秒計測します。
- 成功結果をC発行の同一IDで即時保存し、保存完了後に結果画面へ進みます。保存失敗時は同じ結果で再試行できます。
- 任意の体調と外部体温、定型レポートを既存記録へ追記します。履歴と個別・全件削除を接続しました。
- 今日を除く7暦日で有効な自己申告値が3件以上ある場合に中央値を表示し、不足時は基準値蓄積中とします。
- SQLiteはバージョン2へ移行し、既存の初回説明状態を保護します。未測定値はNULL、画像・動画は保存しません。

SwiftのAIブリッジ、通知、rPPG心拍推定、顔色特徴量は未接続・未実装です。レポートは既存の定型文を使います。実機での撮影性能・品質閾値・通し動作の検証結果は `.codex/STATE.md` に記録します。

## 開発と実機起動

Flutter 3.47.7 / Dart 3.13.5。正式対象はiPhone 17 / iOS 27以降です。Androidは未検証です。

```sh
flutter pub get
dart run build_runner build
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter devices
tool/flutter_with_xcode.sh run --release -d <device-id>
```

このMacで利用する既存SDKは `/private/tmp/os2604-c-flutter`、PUB_CACHEは `/private/tmp/os2604-c-dart/pub-cache` です。必要ならSDKのbinをPATHへ追加してください。Xcode選択のラッパーはシステム設定を変えずに動作します。

実機の署名チームはGit除外の `ios/Flutter/LocalSigning.xcconfig` に設定し、個人設定をコミットしません。ML Kitの組込にはCocoaPodsが必要です。iPhoneを接続してロックを解除し、必要な信頼・開発者モードの設定を端末で行ってください。

ホーム画面から単独起動する確認にはRelease版を使用します。Debug版の実機起動にはFlutterまたはXcodeが必要です。

## 資料

- `AGENTS.md`：開発ルール
- `docs/app-spec-source.txt`・`docs/team-plan-source.txt`：仕様と分業
- `docs/implementation-decisions.md`：契約・承認済みの保存仕様
- `docs/c-integration.md`・`docs/c-ai-integration.md`：CのAPIと制約
- `.codex/STATE.md`：この作業環境での検証結果と次の手順
