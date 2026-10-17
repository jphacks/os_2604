# 15秒健康チェック — os_2604

毎朝、顔位置確認後に15秒間撮影し、記録と過去の自分との差を振り返るFlutter製の検証用MVP。診断を目的としません。

C担当の計測API・iOSカメラ接続・品質判定・ScanWidgetは [C担当の接続メモ](docs/c-integration.md) を参照してください。

デモ手順・受け入れ試験表は [デモ手順](docs/demo-guide.md) を参照してください。

[![IMAGE ALT TEXT HERE](https://jphacks.com/wp-content/uploads/2026/07/IMG_5316.png)](https://www.youtube.com/watch?v=piaNsc6ilBI)

## 環境

Flutter **3.47.7 stable / Dart 3.13.5**。推奨版は `.flutter-version` に記録。

正式対象は **iPhone 17 / iOS 27以降**。

```sh
flutter pub get
dart run build_runner build
flutter devices
```

## 検証

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```
