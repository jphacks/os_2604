# 現在の作業状態

## 2026-10-17 B-01 Flutter基盤・実機起動

- 担当：ユーザーはB。今回の担当は① 基盤と共有契約案。作業ブランチはBを起点に作成。B→mainはユーザーがマージする。
- 元リポジトリ：`/Users/mumekun/Documents/GitHub/os_2604`、ブランチB、開始コミットaaace3a。元の作業ツリーは変更していない。
- 作業先：`/Users/mumekun/Documents/GitHub/os_2604-b-foundation`、ブランチ `codex/b-foundation`。独立worktreeに基盤変更を実装。コミットとB統合の履歴はGitで確認すること。

## 決定と実装

- ユーザー指定：正式対象はCと同じiPhone 17 / iOS 27以降。手元のiPhone 15は追加確認用。ユーザー申告はiOS 26.4だったが、接続でiOS 26.6.2を検出した。
- ユーザー指定：BのSDKをCのDart 3.13.5へ合わせる。Flutter公式配布一覧で対応するstable 3.47.7を確認し、MacのFlutterを3.41.6から3.47.7へ更新済み。
- 現在の環境：Flutter 3.47.7 / Dart 3.13.5 / Xcode 26.4。Xcodeのシステム選択先はCommandLineToolsなので、iOSコマンドは `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` を指定する。Android SDKは未導入。
- 実装：iOS/Android生成構成、日本語MaterialApp、アプリ入口、6画面のルート、未実装表示付きの仮画面、画面遷移テスト、README。
- pubspecの最低SDKをDart 3.13.5 / Flutter 3.47.7へ変更し、lockfileを新SDKで解決。.flutter-versionにも3.47.7を記録（自動切替機構ではない）。
- Flutter更新による公式の構成更新：analysis_options.yamlの生成・プラットフォームディレクトリ除外、iOS deployment target 15.0。CのML Kit導入時は採用版の最低OSを再確認する。
- 個人の署名情報はGit除外した `ios/Flutter/LocalSigning.xcconfig` のみ。Debug/Release.xcconfigは任意でこのローカルファイルを読み込む。共有pbxprojには個人のDEVELOPMENT_TEAMを保持していない。
- 開発用識別子はiOS `com.example.os2604`、Android `com.example.os_2604`。配布用は未確定。

## 検証

- 新SDKで `flutter pub get` 成功。
- 新SDKで `dart format --output=none --set-exit-if-changed lib test` 成功（5ファイル、変更なし）。
- 新SDKで `flutter analyze` 成功（指摘なし）。
- 新SDKで `flutter test` 成功（1件：全5遷移と戻る操作）。
- 新SDKで署名付き `flutter build ios --release` 成功（14.2秒、Runner.app 14.8MB）。
- 新SDKのRelease版をiPhone 15 / iOS 26.6.2へdevicectlでインストールし、CLIのLaunched applicationで起動を確認。
- 直前の旧SDK Release版では、ユーザーがホーム画面から起動して「15秒健康チェック」「開発用の画面骨格」の表示を確認済み。新SDK版の画面目視・各画面の手動操作は未確認。
- 正式対象iPhone 17 / iOS 27以降、Androidビルド、カメラ・顔検出・保存・通知・AIは未検証。製品機能はまだ未実装。
- git diff --check成功、LocalSigning.xcconfigのGit除外を確認。

## 失敗と対処

- 日本語UIでWidgetTester.pageBackの英語tooltip依存により失敗。実際のBackButtonをタップするテストへ修正して成功。
- Debug版をホーム画面から開く案内は不適切だった。ユーザー画面でFlutterの起動制限を確認し、単独起動できるRelease版へ変更。
- Untrusted Developerはユーザーによる開発者署名の信頼で解消。Release版のCLI起動失敗は端末ロックが原因。ロック解除後の起動を確認。
- 容量不足でビルドが失敗し、ユーザーが約10GB確保。その後のFlutter upgradeが全プラットフォームの取得中に再び容量不足で終了。ソース更新とDart更新は完了していたため、再生成可能なAndroidおよびmacOS配布用SDKキャッシュを整理し、`flutter precache --ios` でiOS用取得を完了。無関係なユーザーデータは削除していない。直近確認時の空きは約7.3GiB。
- Android/macOS配布用のSDKアーティファクトは削除済みのため、必要になった際に再取得する。FlutterはHomebrew配置のSDKをflutter upgradeで更新したため、Homebrewの旧インストール版表記よりflutter --versionを実体の確認に使う。

## C連携と次の手順

- `/Users/mumekun/Downloads/c-integration.md` を読み取り確認済み。Cの単一時計、進捗通知、キャンセル、B側即時保存の案はB案と大筋一致。共有文書は合意・実装指示と区別し、依存追加・共通API・閾値はまだ未確定。
- 共有契約案：`docs/b-foundation-contract-proposal.md`。共有型・DB・計測APIは未実装。
- Cの実コードはまだこのworktreeへ統合・検証していない。Dartバージョンが揃ってもCコードの統合合格とは扱わない。
1. 今回はユーザーから基盤のコミット・push・Bへのマージとpushを明示承認済み。統合後はBを基点に②③の作業ブランチを作る。mainへのマージは引き続きユーザーが行う。
2. B/Cの共有型・計測・保存・比較・削除契約を合意し、②③へ実装指示を出す。
3. ②は統合後のBから画面実装。①がapp.dartへ接続する。
4. ③は契約合意後にDB実装。依存・コード生成設定は①へ要求する。
5. ④は試験計画と読み取りレビューを先行。通知はP0の進捗を見て着手する。
6. 共通設定・依存・lockfile・main.dart・ネイティブ構成・STATEは①が管理する。

## Git

ユーザーの明示依頼に従い、codex/b-foundationの基盤をコミット・pushし、Bへ統合する。mainは操作しない。成功したコミット・統合先はGit履歴と最終報告で確認する。今回の依頼は直接のB統合で、PR作成の依頼はない。
