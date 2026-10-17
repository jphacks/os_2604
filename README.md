# 15秒健康チェック — os_2604

毎朝、顔位置確認後に15秒間撮影し、記録と過去の自分との差を振り返るFlutter製の検証用MVP。診断を目的としません。

## 現在の実装

- 初回説明と確認状態のSQLite保存。次回起動はホームへ進む。
- 設定の読込・書込失敗表示と再試行、重複保存・古い非同期応答の抑止。
- ホーム、Cの計測サービスが未接続であることを示す画面。
- 任意の体調1〜5と外部体温入力部品。結果画面・健康記録の保存への接続は未実施。
- 今日を除く直近7暦日の有効記録から自己申告の中央値を求める分析関数。健康記録との接続は未実施。
- C向けカメラ・ML Kit依存とiOSビルド設定。

履歴・設定・結果は仮画面です。健康チェックの実計測・健康記録DB・削除・レポート・通知はまだ利用できません。CのAPI実装は文章で回答を受領しましたが、コード本体のpush待ちです。未接続を空の履歴や成功として表示しません。

## 環境

Flutter **3.47.7 stable / Dart 3.13.5**。推奨版は `.flutter-version` に記録（自動切替なし）、pubspecにも最低条件を指定しています。

正式対象は **iPhone 17 / iOS 27以降**。iPhone 15 / iOS 26.6.2は追加検証用。Androidの生成構成はありますが、SDK未導入・ビルド未検証です。Chrome/macOSは製品の対象に含めません。

```sh
flutter pub get
dart run build_runner build
flutter devices
```

DB変更時はコードを再生成し、g.dartも差分確認してください。既存のDBを削除して作り直す運用は禁止です。

## iOSの起動・ビルド

このMacはXcode 26.4がインストール済みですが、xcode-selectがCommandLineToolsを指しています。native assetのhookがDEVELOPER_DIRを引き継がないため、単なる環境変数指定だけでは追加依存のビルドに失敗します。

既存のXcodeをこのコマンドだけで参照するラッパーを用意しています。システム設定は変更しません。

```sh
tool/flutter_with_xcode.sh build ios --release --no-codesign
tool/flutter_with_xcode.sh run --release -d <device-id>
```

Xcodeの場所が異なる場合はDEVELOPER_DIRで指定してください。ラッパーは一時的なxcrunのみをPATHへ追加し、終了時に生成物を除去します。

署名チームはGit除外済みの `ios/Flutter/LocalSigning.xcconfig` に設定します。

```xcconfig
DEVELOPMENT_TEAM = <自分のチームID>
```

Debug版はFlutter/Xcodeから起動します。ホーム画面から直接開く場合はRelease版を使います。iPhoneのロックを解除し、必要な開発者署名の信頼設定を本人が行ってください。

iOS最低バージョンはML Kitの要件に合わせ15.5。カメラの利用目的を設定済みで、音声を無効にするCの実装に合わせマイクの利用目的は追加していません。カメラ・顔検出が実機で動いたことを示す設定ではありません。

## 検証

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
git diff --check
```

現在28件成功。画面callback・小画面/拡大文字、起動ゲートの読込/保存失敗と競合、実SQLiteの冪等性・書込失敗・file再open、比較境界・中央値、任意入力を確認します。fakeによる失敗注入と実SQLite試験は区別しています。

追加依存を含む署名なし/署名付きiOS Releaseビルドは成功。今回版をiPhone 15へインストールしましたが、端末ロックでCLI起動は拒否され、画面操作は未確認です。正式対象での実計測・保存の通し試験は未実施です。旧基盤のFlutter 3.41.6版はユーザーによるiPhone 15の画面表示確認、新SDK 3.47.7版はCLI起動を確認済みですが、今回の説明保存・カメラ依存追加後の実機試験とは区別します。

ML KitにはCocoaPods併用と、Apple SiliconのiOS 26以降シミュレータ用arm64非対応の警告があります。シミュレータを正式実機の代替にしません。

## 担当と資料

- `lib/app.dart`, `main.dart`, 依存・native設定：①統合
- `lib/screens/`, `widgets/`：②画面
- `lib/services/db/`, `analysis/`, `settings/`：③保存・分析
- `docs/b-verification-plan.md`：④独立レビュー・受け入れ試験
- `lib/models/`, `features/scan/`, `services/ai/`：Cの実装と共同契約（本体取得待ち）

仕様正本は `docs/app-spec-source.txt` と `docs/team-plan-source.txt`。現在の決定事項は `docs/implementation-decisions.md`、Cとの接続状況は `docs/c-integration-status.md`、分担は `docs/b-team-plan.md`、作業状態は `.codex/STATE.md` を参照してください。

作業ブランチはBから作成し、取り込み先もB。mainへのマージはユーザーが行います。
