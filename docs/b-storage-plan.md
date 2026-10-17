# B③ 保存設計・Drift導入調査

2026-10-17。B `fb6878b` / `codex/b-storage`。**調査・提案であり、共有API・製品スキーマの合意または実装ではない。** 所有範囲は本書のみ。共通設定・STATE・依存は①が管理する。

## 確定している制約

- 計測終了直後、AI生成より先に保存し、保存完了を待つ。AI失敗で計測結果を失わない。
- 未測定値はSQL NULLへ写し、0や正常値で補完しない。画像・動画は保存しない。
- 追記は同じ記録IDへの更新。削除済みIDを遅延応答で再作成しない。
- 中断を履歴に残さない案、個別＋全件削除案、今日を除く7日・3件比較案は未承認。保存対象・検索条件として固定しない。
- 正式対象iPhone 17 / iOS 27以降。iPhone 15確認で代替しない。

## ①へ渡す依存・生成要求（採用候補）

```yaml
dependencies:
  drift: ^2.35.1
  drift_flutter: ^0.3.1
  path_provider: ^2.1.6
dev_dependencies:
  drift_dev: ^2.35.1
  build_runner: ^2.16.1
```

[公式Setup](https://drift.simonbinder.eu/setup/)を基点に、drift/drift_devのpatchは[公開バージョン一覧](https://pub.dev/packages/drift_dev/versions)で2.35.1を確認した。公式ページ本文の2.35.0という例と区別する。drift_flutter 0.3.1とdrift_dev 2.35.1の最低Dartは3.10。Dart 3.13.5はこの条件を満たすが、Flutter 3.47.7全依存との解決成功・iOSビルド成功とは別。

[Native公式資料](https://drift.simonbinder.eu/platforms/vm/)ではdrift 2.32以降に旧sqlite3_flutter_libsの追加は不要。sqlite3 3系のnative assets構成を使い、古い導入記事に従ったsqlite3_flutter_libs/sqlcipher_flutter_libsの手動追加やPod設定を行わない。sqlite3はまず推移依存で解決し、製品コードが直接importする場合だけ直接依存へ昇格する。テストは既存flutter_testを利用し、testの固定追加は不要。path_providerはDB配置を明示する場合の直接依存候補で、drift_flutterの既定配置だけを使いimportしなければ省略可能。

DB接続はdrift_flutterのdriftDatabaseを入口に、アプリで単一接続を共有する案。背景isolateの選択・保存先を実装時に確認する。UI isolateに同期I/Oを置かず、テストにはQueryExecutorを注入できる構造にする。MVPで複数読み取りisolate・readPool・独自WAL調整は導入しない。

共有契約が固まったら③が `lib/services/db/` 内にDB定義＋ `part '...g.dart'` を作り、①の依存追加後 `dart run build_runner build` を実行する。通常SQLite・Dart Table定義に初回のbuild.yamlは必須ではない。生成物も差分レビュー対象にする。競合出力は原因確認後に対処し、最初から削除フラグで他担当の生成物を消さない。schemaVersion=1を初回候補とし、次の変更時にスキーマexport・移行テストを整える。自動DB削除による作り直しは禁止。

## 書き込みと競合制御の提案

以下の名前はすべて契約案。型・enum・列名はまだ定義しない。

1. `insertMeasurement`：Bが一度だけ発行したIDでinsertし、commit後に保存済み結果を返す。insertと自己申告・report追記をupsert一つに統合しない。重複IDは明示duplicateとして扱い、再試行の場合は同じ計測か検証して既存を返す方針を①と合意する。失敗時はメモリ内の計測結果と同じIDを保持し、再試行で二重記録を作らない。
2. 保存成功後に自己申告を同一IDへ更新する。省略と明示nullクリアを区別する（Drift CompanionのabsentとValue(null)）。計測由来フィールドを追記の全行replaceで消さない。日時はUTCの一貫した表現、表示・日付境界は別責務とする案。ミリ秒精度の要否は共有型に合わせる。
3. 自己申告の変更ごとに入力revisionを増加し、旧reportを無効にする。入力更新・revision増加・無効化は同一transaction。旧本文を消すか保存してstale非表示にするかは未合意だが、古い内容を現在の結果として表示しない。AI呼び出しはtransactionの外。
4. 生成開始時に、計測・自己申告・比較値を一つの入力snapshotにし、inputRevisionと一意なrequestTokenを確保する。同じrevisionの再生成もtokenを更新し、後から届いた前回応答を拒否する。比較元も自己申告後の入力に含める。履歴削除・変更で進行中reportを無効化するかは①/Cと決める（必要ならhistoryRevisionも照合）。
5. `applyReportIfCurrent(id, inputRevision, requestToken, report)`：SQL UPDATEのWHEREにID・revision・最新tokenを含め、本文・実モード・生成日時を同時更新する。Dartで事前に存在確認して無条件UPDATEするだけでは競合を防げない。更新行数1ならapplied、0なら非適用。削除後もinsertしない。0をmissingとstaleに区別する必要があれば同一transactionで再照会し `missing / stale` を返す。最小契約は `applied / notApplied` でも成立する。UIでDB例外と非適用を混同しない。
6. 削除はDBのDELETEに集約しcommit後だけ成功表示。個別／全件の公開範囲はユーザー承認後。生成中の削除はキャンセルに加えて上記条件付きUPDATEで保護する。新規計測は削除されたIDを再利用しない。全削除後も同様。DBファイル削除は接続中transactionや再openと競合するため全件DELETEとは区別する。

これはDB内部の楽観的競合制御案であり、CへDB列を露出する必要はない。Bが生成前後をラップし、Cは渡されたsnapshotに対するreportを返す形で成立する。アプリ再起動時の未完了生成は結果の再生成候補に戻し、未完了状態を成功扱いしない。

## 実DBでの検証計画（まだ未実施）

モックRepositoryだけで保存合格としない。[Drift Testing](https://drift.simonbinder.eu/testing/)が説明するQueryExecutor注入とNativeDatabase.memory()で、実SQLiteの制約・NULL・UPDATE件数を検証する。永続化だけは一時ディレクトリの実ファイルDBを使用する。架空の非個人値をfixtureとし、接続・stream・一時ファイルをtearDownで閉じる。

| ケース | 期待する観測 |
| --- | --- |
| NULL往復／nullクリア／省略更新 | 未測定NULLのまま。省略は既存値維持、明示nullだけクリア。出典enumと値の整合も確認 |
| AIより先の保存 | AI開始をCompleterで止めても別の取得で計測が存在。insert失敗時にAIを開始しない |
| 同一ID追記・重複insert | 自己申告→report後も件数1・計測値維持。重複が意図せず上書きされない |
| rollback | transactionで自己申告/revision/report無効化後に例外を注入し、全フィールドが変更前のまま。初回複合保存も部分行なし |
| 古いreport | rev1生成→rev2自己申告→rev1完了で適用0件。rev2のみ適用。完了順をCompleterで両順に固定 |
| 同一入力の再生成 | token1→token2開始→token2完了→token1完了でtoken2を維持 |
| 削除との競合 | 生成→削除commit→生成完了で行数0、再挿入なし。全件削除採用時も同じ |
| 永続化 | file DBへ保存・追記→close→新接続で再open、NULL/ID/revision/report一致。削除後再openも記録なし |
| 保存エラー | executorの失敗注入でUI成功/AI開始なし。iOSのディスク不足や保護状態は別の実機試験で確認 |

[Transaction資料](https://drift.simonbinder.eu/dart_api/transactions/)に沿い、内部queryをすべてawaitする。streamはcommit後に一貫した状態を観測することも検証する。日付・比較境界テストは承認条件確定後に追加し、現時点で7日/3件をassertしない。正式対象でオフライン保存→終了→再起動→履歴・削除まで実機確認を行う。

## C回答が必要な最小項目

- ScanOutcomeの成功payloadの型・フィールド・nullability・品質と有効性、計測時刻と経過時間の精度。B保存IDとCセッションIDの分離。
- Cは保存をせずBが直後保存する分担、cancel完了後に旧セッション成功が来ない保証。
- report入力snapshot（集計はBか）と戻り値（本文・実mode・生成時刻・失敗/定型）。Cが入力tokenを返すか、Bクロージャで保持するか。

保存対象・削除範囲・比較条件は人間の決定待ちでありC回答だけで確定しない。自己申告後の既存report表示、比較履歴変更時の無効化、保存失敗時の再試行UIは①②Cとの接続決定が必要。

## 今回の確認と限界

- 指定のAGENTS、STATE、共有契約案、未決事項、B→C返信、仕様の保存・概念モデル節を確認。開始時worktree clean、ブランチcodex/b-storage。
- 公式Drift/pub.devを閲覧して上記導入候補を確認。依存未追加、生成・DB試験・iOSビルドは未実施。
- Dartバイナリの直接実行で3.13.5を確認。flutter --versionはSDK cacheへの書込がsandboxに拒否され実行不可。Flutter 3.47.7は基盤の既存確認記録を参照。
- `/private/tmp/os2604-storage-probe` の独立pubspecで製品と同じSDK条件・flutter_test付き依存解決を試行。結果は下記に追記。製品pubspec/lockfileは変更していない。
- 一時依存解決はexit 69：`Got socket error trying to find package path_provider at https://pub.dev.`。ネットワーク環境の失敗であり、候補版の互換/非互換は未判定。rootが許可されたネットワーク環境で同条件の解決・lock確認・生成・analyze/test・iOSビルドを行う必要がある。rootは共通SDK 3.47.7 / 3.13.5を検証済みと連絡済み。

## ①による追加の依存解決確認

rootが同じ一時パッケージでネットワーク許可のある実行に切り替え、flutter pub getが成功（91依存）した。解決版はdrift 2.35.2、drift_dev 2.35.1、drift_flutter 0.3.1、path_provider 2.1.6、build_runner 2.16.2、sqlite3 3.7.1。旧名のsqlite3_flutter_libs / sqlcipher_flutter_libsもEOL版が推移依存に現れたが、直接依存として追加していない。製品pubspecは未変更。成功したのは一時パッケージの依存解決だけであり、DB生成・実SQLite試験・iOSビルドの成功ではない。

## 現在地の更新

ユーザーが4つの履歴仕様を採用済み。健康記録の型はCの実装取得を待つ。一方、共通計測型に依存しない説明確認のSQLite保存と、承認済み条件でのB分析関数は実装・統合済み。導入済みの依存・実行結果はSTATEとREADMEを参照する。
