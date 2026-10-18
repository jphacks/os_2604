# A視点の最終UIレビュー

2026-10-18 / レビュー：Codex（AのUI・UX観点）。対象：`rppg_accuracy_validation_integration` の `315cf61` ＋通常／研究切替・schema v5の未コミット差分。LED版とremote mainの後続変更は対象外。最新版Figmaとの一致は確認していない。

## 判定

**blocker 0 / should 2 / nice 1。レビュー実施済み、最終UI承認は保留。**

開始操作の見つけやすさと状態案内の2点は原則修正する。今回はレビューの依頼のため、製品UIは変更していない。研究モードの明示、未測定表示、生成モード、保存失敗の明示、再試行・削除確認の導線は維持できている。

## should（原則修正）

### A01：撮影画面の「開始」が標準サイズでも見切れる

- 対象：`lib/screens/scan_screen.dart:224`〜291（研究説明＋全幅3:4プレビュー＋操作部を同じスクロール列へ配置）。
- 再現：iPhone 17 Simulatorから得た全画面402×874、SafeArea上62／下34、文字100%に合わせたFlutter描画。通常モードの初期表示。レビュー基準393×852でも再現。
- 根拠：iPhone 17相当では「開始」の文字領域はy=836〜856、下部SafeAreaの上端はy=840。基準393×852でも文字y=809〜829に対しSafeArea上端y=818。ボタンと文字が下端で一部見切れる。研究モードや文字拡大時はさらに下になる。スクロールすれば操作できるため、進行不能のblockerにはしない。
- 影響：カメラを開始するための主要操作が最初の画面で読めず、ユーザーが待機したりスクロールを探したりする。
- 修正案：開始／再試行操作をSafeArea内の固定領域に置く、または表示領域に合わせてプレビューと説明の高さを調整する。15秒の時計・顔品質・計測座標の契約は変えない。
- 再確認：通常／研究、標準文字／200%で開始・再試行が読めて押せる。撮影中は顔ガイドと残り時間も確認できること。

[iPhone 17相当の初期表示](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/iphone17-scan-phone-100.png) / [基準画面の初期表示](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/scan-phone-100.png) / [研究モード](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/scan-phone-100-research.png)

### A02：未開始・保存失敗時の案内が実際の処理状態と合わない

- 対象：`lib/screens/scan_screen.dart:247`〜249、305〜314。
- 再現：撮影画面を開いてまだ開始していない状態。プレビュー欄は「カメラを準備しています」、その下は「顔を枠に合わせて、開始を押してください」。
- 根拠：実カメラの初期化は`_start()`→`startHealthScan()`の後に行われる。開始前は準備処理が進行していない。保存失敗時も、計測済みの結果を再保存する状態なのに同じ準備・開始案内が残る。描画ハーネスに加え、`health_scan_controller.dart`と`ScanWidget`の初期化／後片付け経路を照合した。
- 影響：開始前はカメラ起動を待ち続ける原因となり、保存失敗時は再計測が必要だと誤解させる。
- 修正案：開始前は「開始を押すとカメラを起動します」、実際の初期化中だけ「カメラを準備しています」、保存失敗時は「計測は完了しています。保存を再試行してください」等へ状態別に分ける。文言は提案であり確定仕様の変更ではない。保存再試行でカメラを再起動しない。
- 再確認：開始前・許可待ち・準備中・計測中・計測失敗・保存失敗がそれぞれ適切に説明されること。

[保存失敗時の証跡](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/scan-savefailed-phone-100-action.png)

## nice（任意）

### A03：文字拡大時は結果のラベルと値を縦に並べる

`result_screen.dart:372`〜378のラベル幅110固定により、320×568・文字200%では「計測モード」「計測日時」が単語途中で折り返され、日時の値も細かく改行される。情報はスクロールして読め、レイアウト例外もないため任意改善。大きい文字ではラベルを値の上へ置くと読みやすい。P0の修正を遅らせない。

[拡大時の研究結果（架空データ）](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/result-research-small-200.png)

## 確認できたこと

| 範囲 | 結果と限界 |
| --- | --- |
| 初回説明・ホーム・撮影・通常結果・研究結果・履歴・設定 | 基準393×852・100%と小画面320×568・200%で描画。日本語フォントを読み込み、スクロール後の操作も確認 |
| 権限拒否・中断・保存失敗 | 同じ2表示条件で説明と再試行が表示される。保存失敗は成功として表示されない。A02の状態案内には改善が必要 |
| Flutterの描画検証 | 20条件＋iPhone 17相当の撮影画面1条件、計21条件成功。RenderFlex overflow等のレイアウト例外なし。これは全ての画面を最終UI承認した意味ではない |
| 操作領域・ラベル | 表示中コントロールの44pt領域とラベル検査は20条件で指摘なし。結果の体調選択・体調保存・体温保存・ホーム操作もスクロール後に追加確認 |
| コントラスト候補の切り分け | ピクセル解析の警告3画面は実際の文字色・背景色を照合。該当箇所は5.47〜16.31:1で、色指定の基準不足としては報告しない。全画面の認証を意味しない |
| 研究・未測定・出典 | 研究モードと注意文、rPPGの試験的推定、外部体温、nullの未測定表示を確認。正常範囲や精度保証は表示していない |
| iOSネイティブ下部タブ | 製品`CameraTabs`をコピーした一時SwiftUI専用iPhone 17 / iOS 27 Simulatorホストで、通常・最大文字サイズの見切れなし。UIテスト1件成功、3つの日本語ラベル・タップ切替・選択時isSelectedと非選択時false・各93.33×76ptの領域を確認。実アプリ全体のPlatformView統合や実機VoiceOverの読上げ合格へ読み替えない |
| Reduce Motion | `CameraTabBar.swift:61`／93で設定を読みアニメーションを無効にする実装を静的確認。OS設定を切り替えた実行確認は未実施 |

[ネイティブタブ・最大文字サイズ](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/native-tabs-accessibility5-history-selected.jpg) / [画面寸法](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/native-tabs-geometry.jpg) / [UIテスト証跡](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/native-tabs-uitest-evidence.txt)

## 証跡・実行条件

- Flutter描画は実物の画面Widget＋メモリ内SQLite＋偽カメラ／通知を使用。**全て架空データで、実機の健康値・顔画像を含まない**。カメラ性能やAIの実機試験の代替ではない。
- 日本語フォントはローカルのヒラギノ角ゴシック、Material Iconsを読み込んだ。iPhoneのフォント・SafeArea・描画との完全一致は保証しない。ネイティブタブ以外の下部バー画像はFlutter代替部品。
- 診断用ハーネス：`/private/tmp/a_ui_review_test.dart`。ログ：`/private/tmp/a-ui-review-complete.log`、追加1条件は`/private/tmp/a-ui-review-iphone17.log`。集計と画像：[/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/results.json](/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review/results.json)。製品のlib/testにハーネスや架空記録を追加していない。
- 初回はハーネスのSemanticsHandle解放漏れで終了時に失敗。ハーネスを修正して再実行し、最終20条件＋iPhone 17相当1条件成功。製品UIの不具合には数えない。
- Nativeホストの実測：SafeArea内402×778、上62／下34、全画面402×874。ホストは停止済み、MCP設定も元へ復帰。実際のVoiceOver音声とFlutter埋込時のフォーカス連携は未確認。
- 通常版のiPhoneと健康記録には触れていない。既存の279件成功は前工程の結果で、今回再実行したものとしては扱わない。
- ネイティブタブの証跡は一時SwiftUIホストによるもの。デモ用の実機アプリのスクリーンショットとして流用しない。

判断の基準は[製品仕様](app-spec-source.txt)、[決定事項](implementation-decisions.md)、[Flutterのアクセシビリティ確認項目](https://docs.flutter.dev/ui/accessibility)、[W3Cのコントラスト説明](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)。数値だけで最終判断せず、操作可能性と実際の状態に合う文言を優先した。

## 次の手順

A01・A02を修正して撮影画面を再確認し、実機iPhone 17で操作と文言を最終確認する。A03は任意。最新版の中断・オフライン試験や精度評価の状況は[C確認票](c-validation.md)と区別する。
