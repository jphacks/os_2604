# 15秒健康チェック — os_2604

毎朝、顔位置確認後に15秒間撮影し、記録と過去の自分との差を振り返るFlutter製の検証用MVP。診断を目的としません。

## 現在の実装範囲

FlutterのiOS / Android初期構成、日本語Material UI、アプリ入口、6画面分のルートを用意しています。起動時のホームは開発用ランチャーです。初回設定・撮影・結果・履歴・設定は未実装のプレースホルダーで、撮影・計測・権限取得・保存・通知・AIはまだ動作しません。

## 開発環境

共通環境：Flutter 3.47.7 stable / Dart 3.13.5、macOS 26.4.1 arm64。C担当のDartに合わせて更新済みです。推奨Flutter版は `.flutter-version` に記録し、pubspecでも最低バージョンを指定しています（このファイルだけでSDKは自動切替されません）。初回構築はFlutter 3.41.6 / Dart 3.11.4で実施しました。

```sh
flutter --version
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <device-id>
```

対象はiOS / Androidです。Android SDK、iOS用の完全なXcode設定、および対象端末を各開発環境で準備してください。iOS実機の署名チームは開発者がローカルで設定します。生成時に選択された個人のチーム情報は共有プロジェクトから除外しています。

アプリ識別子はFlutter生成時の開発用（iOS: `com.example.os2604`、Android: `com.example.os_2604`）です。配布用識別子は未確定です。カメラ・通知の権限とネイティブ設定は各機能の導入時に追加します。

2026-10-17時点の本作業環境ではAndroid SDK未検出。iPhone 15 / iOS 26.6.2をUSB接続し、署名付きDebugビルドとインストールを確認済みです。Xcode 26.4はインストール済みですが、システムの選択先はCommandLineToolsのため、この作業では `DEVELOPER_DIR` でXcodeを指定しています。iPhone 15で基盤画面の起動表示は確認済みです。カメラ・AIは未実装で、動作未検証です。Chrome / macOSが検出されても製品の対応OSには含めません。

## 検証

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

`test/app_navigation_test.dart` は開発用ホームから各プレースホルダーへの遷移と戻る操作を検証します。初回設定の永続化や計測の受け入れ試験を代替しません。

初期構築時は整形チェック・解析・テスト（1件）、Dart/アセットbundle生成、Xcode 26.4での署名なしiOS Debugビルドが成功しました。更新後のFlutter 3.47.7 / Dart 3.13.5でも依存解決・整形チェック・解析・テスト（1件）・署名付きiOS Releaseビルド・実機インストールとCLI起動が成功しています。生成物は `build/ios/iphoneos/Runner.app`。追加でiPhone 15 / iOS 26.6.2への署名付きReleaseビルド・インストールを確認し、ユーザーがホーム画面から起動して「15秒健康チェック」「開発用の画面骨格」を確認しました。正式対象のiPhone 17 / iOS 27以降は未検証です。

ネイティブ環境の準備後：

```sh
flutter build apk --debug
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer flutter build ios --debug --no-codesign
```

ビルド成功と実機試験は区別してください。計測・保存・AIの受け入れ条件は仕様書と分業書に記載しています。

## 構成と担当

| ファイル・領域 | 役割・窓口 |
| --- | --- |
| `lib/main.dart` | アプリ起動 / ① |
| `lib/app.dart` | MaterialApp・日本語化・画面接続 / ① |
| `lib/navigation/app_routes.dart` | 6画面のルート名 / ① |
| `lib/foundation/scaffold_pages.dart` | ②の画面実装へ置き換える仮画面 |
| `lib/screens/`, `lib/widgets/` | ② 画面 |
| `lib/services/db/`, 対応する `test/` | ③ 保存 |
| `lib/services/notifications/`, 対応する `test/` | ④ 通知（P1） |
| `lib/models/` | B/C合意後の共通型。現時点では未実装 |
| `lib/features/scan/`, `lib/services/ai/` | C担当 |

依存・lockfile・main.dart・ネイティブ構成の変更は①に集約します。各担当の独立worktreeで作業し、PRの取り込み先は `B`。マージは人間が行います。

## 仕様と次の手順

- `AGENTS.md`：開発ルール
- `docs/app-spec-source.txt`：製品仕様の正本スナップショット
- `docs/team-plan-source.txt`：分業・進行・受け入れ試験
- `docs/implementation-decisions.md`：未決事項
- `docs/b-foundation-contract-proposal.md`：共有契約案（未合意）
- `.codex/STATE.md`：現在の作業状態

次は優先実機・OSとB/Cの契約を確認し、②の画面、③の保存を接続します。詳細UIとDBを先に別々の共通型で実装しないでください。

Flutter初期構築は[公式手順](https://docs.flutter.dev/reference/create-new-app)に沿っています。

## iPhoneで単独起動する場合

Debug版はFlutterまたはXcode経由で起動します。ホーム画面から直接起動して確認する場合は `flutter run --release -d <device-id>` を使用します。初回は端末の開発者署名の信頼も必要です。

iOS実機の署名チームは、Git除外済みの `ios/Flutter/LocalSigning.xcconfig` に `DEVELOPMENT_TEAM = <自分のチームID>` として設定できます。Debug/Releaseのxcconfigから任意で読み込みます。個人の設定をコミットしないでください。

容量確保後、Release版への入れ替えとユーザーによる実機画面表示確認が完了しました。CLIから起動する場合はiPhoneのロックを解除してください。正式な検証対象はCと同じiPhone 17 / iOS 27以降で、手元のiPhone 15は追加検証用です。
