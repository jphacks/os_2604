# 2026-10-18 カメラ比率・カウントダウン逆戻り修正

- PR提出前の最終検証：整形95ファイル変更なし、analyze指摘なし、全342テスト成功。ユーザー依頼で今回の変更をまとめてcommit・pushしmain向けPRを作成。
- 追加UI調整：履歴一覧の記録時刻を、品質ラベル横から左側の日付・曜日の下へ移動。日付欄のない今日のコンパクト行は時刻を維持。関連24テストとReleaseビルド成功。今回iPhoneが未接続のため履歴配置変更版の導入は未完了。

- ブランチ: `codex/fix-camera-preview-countdown`、main `c548ef2`起点。
- 縦圧縮: 楕円の固定サイズにCameraPreviewを直接配置していた。プレビューの回転を考慮した元の縦横比でBoxFit.cover表示し、余剰部分だけクロップ。顔判定・元フレームは変更なし。
- 逆戻り: 100msタイマーの配信後、古い撮影時刻の有効フレームが進捗を上書きしていた。計測中の経過表示を同一試行内で単調増加に制限。成功判定は引き続き15秒以降の有効終端フレームが必要、再試行では0へリセット。
- 検証: 修正前に1秒→0.95秒の逆戻りを再現。修正後は全342テスト成功、analyze指摘なし。縦横比3:4・9:16・4:3、遅延フレーム・再試行リセットを検証。
- ゲージ追加調整：100ms更新を線形補間し、画面のリフレッシュに合わせて描画。秒数・時計・成功判定は変更なし。視差効果を減らす設定では補間を無効化。関連25テスト成功、analyze指摘なし。
- 署名付きiPhone用Releaseビルド成功（88.7MB）。iPhone15へ上書きインストール・起動成功。見た目と動きのユーザー確認待ち。main未マージ。

# 2026-10-18 PR #13 と研究モードの統合

- ブランチ: `codex/ui-navigation-transitions`。main `d2179fd`（PR #12）を取り込み、app.dart・scan_screen.dartの競合を解消。
- ユーザー承認: 通常／研究切替を設定画面へ移し、新UI・自動開始・アニメーション・フォント・キャラクター・効果音を維持。Liquid Glassの既存PR内実装を追加変更せず維持。
- 設定の研究モードは初期オフ、端末内保存。撮影ルートで読み込んでから該当サービスのみ生成・自動開始。撮影中はモード固定。読込失敗はカメラを作らず再試行、保存失敗は設定を変更せず表示。
- DB schema v6: scan_preferencesテーブル追加のみ。v5からの移行で既存の測定モード・履歴保持、設定の再起動後保持をテスト。Cの通常／研究処理・null・品質条件・結果のモード表示を保持。
- 検証: 整形95ファイル変更なし、analyze指摘なし、全338テスト成功。iPhone向け署名付きRelease最終ビルド成功（88.7MB）。今回の統合版の実機操作は未確認。
- PR #13へpushしレビュー可能にする。mainへのマージは今回行わない。

## 2026-10-18 画面遷移仕様（push/fade/cover/sheet）の反映
- ブランチ `codex/ui-navigation-transitions`（main `444390f` 起点）。未コミット。ユーザー提供の「あさかお 画面遷移仕様」に従う。
- 共通：`lib/navigation/app_transitions.dart`（push=CupertinoPageRoute／fade=0.25秒／cover=下から・下へ／cover内fadeは閉じると下へ）。
- 構成変更：ホームタブを廃止し履歴・設定の2タブ。起動・初回設定完了後は履歴。カメラボタンは計測を cover で開く（`main_tabs_screen.dart`）。`home_screen.dart` は未使用で残置。アプリの説明は設定「情報」→「アプリの説明」から push で再表示（ユーザー決定）。
- 初回設定：入れ子Navigatorで 1-1→1-2 fade／1-2→1-3→1-4 push／1-4許可→1-6 push／1-4「今はしない」・拒否→1-5 fade（仕様変更：従来は1-6直行）／1-5→1-6 push（ユーザー承認済み）／1-6→1-7・1-6' fade。1-7→履歴はゲートで下へ閉じる。
- 計測・結果：3-2→3-3 fade、3-2→4-1 fade、4-1→4-2→4-3/4-2' fade、4-3「履歴に戻る」は下へ閉じて履歴タブ。計測画面を開いた瞬間にカメラ起動・計測開始（ユーザー決定で「開始」ボタン廃止。iOSのカメラ許可確認も画面表示時）。テストの偽計測サービスは同期配信に変更。
- 履歴：5-1→5-4 グラフを push（「リスト」で戻る）、5-1→5-2 push、つぼみ→花をその場でアニメーション。設定：6-2/6-4 push、6-3 をボトムシートに変更。6-5は未実装のまま。
- 検証：format・analyze OK、flutter test 323件成功。iPhone 17（iOS 27.2）にReleaseビルドを導入・起動成功。アニメーションの見た目はユーザー確認待ち。
- ローカル専用（コミットしない）：Bundle ID を `com.koki.os2604` に変更（個人チーム署名用）、CocoaPods 1.17.0 による Podfile.lock 差分。
- キャラ画像：~/Downloads の IMG_1767=ふつう、1768=うれしい、1769=こまった、1770=いそがしい を白背景透過・正方形600pxにして `assets/mascot/{normal,happy,sad,busy}.png`、pubspec に assets 登録、`AsakaoMascot` を画像表示へ。
- 第3回（ユーザー指摘）：履歴の今日カードと「今週咲いた花」を1枚のカードに統合（未完了=デザインの灰色しおれ画像 `assets/mascot/wilted.png`、完了=happy＋品質チップ、タップで今日の記録）。「今日の記録を見る」ボタン廃止、未完了は「下のカメラから15秒で記録できます」。花・つぼみはデザインSVGを `lib/ui/asakao_flower.dart` で描画。リスト↔グラフは push をやめ、スイッチより下だけをスライド＋fadeで切替。設定は見出し下と各グループの間隔を拡大。format・analyze OK、テスト323件成功、iPhone 17へ導入・起動成功。見た目はユーザー確認待ち。
- 第4回以降：フォント同梱（Zen Maru Gothic=見出し、Noto Sans JP=本文・UI・数字、OFL、assets/fonts、アプリ約89MB）。タブ中央カメラを66px・#FF8A5Bに（`ios/Runner/CameraTabBar.swift`、B担当範囲・要共有）。履歴/設定の見出しを共通 `AsakaoStyle.tabTitle` で統一。履歴↔設定は左右スライド。初回設定：1-1「タップしてはじめる」を下部へ、1-2本文から「記録が」削除、1-2〜1-4のドットはNavigator外に固定、下部ボタンは遅れて表示（`AsakaoReveal`）、1-7は状態2行を時間差で表示。1-8 Tipは全体を暗くして操作を止め×で閉じる・カメラを指す吹き出し。テスト323件成功、iPhone 17へ上書き導入。
- 効果音（ユーザー指定）：assets/sounds（~/Downloads の mp3 を英名でコピー）。iOS は AppDelegate.swift の `SoundEffectPlayer`（AVAudioPlayer、ambient＋mixWithOthers＝消音スイッチに従う）を `jp.jphacks.os_2604/sound_effects` で呼ぶ。Dart は `lib/services/sound/sound_effects.dart`。一時停止=3-3表示時、計測完了=計測成功時、撮影準備=3条件がそろった時（試行ごと1回）、初期設定完了=1-7表示時、蕾=今日のつぼみが咲く時。録音開始は不使用（ユーザー決定）。計測中.mp3 は使い所未定（同梱済み・未使用）。テスト330件成功。カード全幅化（履歴の今日カード・詳細の全カード・設定の全カード、線もフレームまで）、詳細の戻るを拡大。
- 検証（第2回）：format・analyze OK、flutter test 323件成功、iPhone 17へ導入・起動成功。見た目・カメラ自動起動の実機確認はユーザー待ち。

## 2026-10-18 計測開始時の誤中断修正
- ブランチ: `codex/fix-scan-countdown-interruption`（全画面UI `82c2e7d` 起点）。
- 準備→計測で兄弟Widgetの型が変わると、キーのないカメラ部分が破棄され、ScanWidgetのdeactivate/disposeがcancelScanを呼んでいた。回帰テストで中断呼び出し2回を再現。
- カメラ部分のルートに固定キーを付与し同一状態を維持。Cの品質条件・15秒時計・背景中断仕様は変更なし。
- 関連24テスト成功、静的解析問題なし、署名付きReleaseビルド成功。iPhone15へ上書きインストール・起動成功。ユーザーより15秒完走を確認済み。最新origin/mainとの競合なし（merge-tree検証）。ユーザー依頼で全画面UIと修正をmainへ統合する。

# 現在の作業状態

## 2026-10-18 PR提出

## 2026-10-18 アサカオデザインを全画面へ反映（Liquid Glassタブバー除く）

- 実機導入追記：このブランチの `82c2e7d` をXcode26.4で署名付きReleaseビルド成功（61.2MB）。iPhone15 / iOS26.6.2へ上書きインストール・起動成功。既存のXcode互換性guardが有効で追加コード修正なし。Liquid Glassタブバー3ファイルの差分なし。各画面の見た目・操作の実機合格はユーザー確認待ち。下記の「実機未確認／既知ビルド問題」は実装時点の記録であり、この導入成功を優先する。

- ブランチ `add/20261018-apply-asakao-design-to-all-screens`（`codex/ui-history` 0f650cb から作成）。PR取り込み先は `codex/ui`、マージは人間。
- 対象：タブバー以外の残り全画面。`camera_tab_bar.dart`／`CameraTabBar.swift`／`main_tabs_screen.dart` は基点から差分なし。
- コミット：d945328 共通UIキット（`lib/ui/asakao_style.dart`、`asakao_widgets.dart`、`asakaoTheme`）／80f80ba 初回設定1-1〜1-7・設定6-1/6-3/6-3'・このアプリについて6-4・通知設定サブページ／f191057＋0f5c962 計測3-1〜3-3・自己申告4-1/4-1'（体温34.0〜42.0℃）・レポート生成4-2/4-2'・結果4-3/4-5／0fedf13 履歴詳細5-2（新ルート `/history/detail`、個別削除は詳細画面へ移動）・推移グラフ5-4（リスト／グラフ切替。1週間＝今日まで7日、1か月＝今日まで30日。体調は棒グラフ、推定心拍は実データのみ折れ線。チャートパッケージ追加なし）。
- ユーザー決定（2026-10-18）：計測開始はボタンのまま（見た目のみ合わせる）／比較条件は「今日を除く直近7日・有効3件以上」を維持（デザインの7日分表記は3日分／3件に書き換え）／追加画面は初回設定・体温範囲チェック・推移グラフ・このアプリについて／os_2604ではCodexレビュー不使用。
- 見送り・相違（詳細は docs/ui/implementation-plan.md「現行仕様との相違点」）：1-8 TipKitは永続化せず初回完了直後のみ／研究・実験モード行6-5は設定が無く未実装／「設定アプリを開く」ボタンは依存追加なしで実装手段がなく手順表示のみ／プライバシーポリシー行は本文なしで省略（免責は「このアプリについて」内）／6-2・6-5'はスクリーンショット未取得／4-4品質不足の結果画面は現行フローで到達せず未実装／結果画面の表示後入力編集ボタンは廃止／品質ラベルpoorは「不足」に統一／クラウドを示唆する文言は不採用／キャラクター画像は仮アイコン（`AsakaoMascot`）、フォントはシステムフォント。
- 検証：dart format OK、flutter analyze 指摘なし、flutter test 322件成功。未確認：実機・シミュレータでの見た目（Mac空き容量不足。Xcode26.4では既存のiOS27 API参照でビルド失敗する既知問題あり、下記参照）。DerivedDataを削除して約2GB確保。
- 次：`codex/ui` へのPR、実機での見た目確認、キャラクター素材の差し替え、6-2／6-5' の確認。

## 2026-10-18 共有デザインへのUI反映（履歴画面・先行ブランチ `codex/ui-history`）

- UI統合用の親 `codex/ui` をmain `247f552`から作成。画面ブランチ `codex/ui-history` を親から作成。PR取り込み先は `codex/ui`、mainへのマージは人間が行う。
- 参照：https://claude.ai/artifact/3whhpT5HvHAutGkch8W1zT#page-dcb81aee8d83 。対象：履歴の一覧／今日の記録／週間の花／記録なし。暖かい白 #FFF8F3、濃茶、コーラル。週間は日曜始まり、同日複数記録は1輪、未来日・品質不足は含めない。
- 維持：削除確認・エラー再試行・記録ごとの結果遷移、計測／AI／DB／通知、Liquid Glassタブバー。比較は「今日を除く直近7日・有効3件以上」。
- 検証：全276テスト成功、analyze指摘なし。390x844はテスト専用メモリDBで画像化し視覚確認。
- iOSビルド：基点mainのAppDelegate.swiftがXcode26.4にないiOS27向けエラー型を参照して失敗。Swift6.4/Xcode27以降でのみ新型をコンパイルするguardを追加（Xcode26では既存GenerationError変換を維持）。Xcode26.4で署名付きReleaseビルド成功（60.7MB）、iPhone15 / iOS26.6.2へ導入・起動成功。Xcode27での再ビルドは未実施。
- 親へ各PRを取り込んでから次の子ブランチを親から切る。

## 以下は基点mainからの過去記録

## 2026-10-17 P2（30fps分離RGBサンプリング・rPPG・顔色特徴量）および B担当DB/履歴・P1 Swift Foundation Models 統合検証

- 追加依頼「PR出してください」に対応し、実装コミット `7ec8c82` をorigin/rppg_accuracy_validation_integrationへ通常push。main向けドラフトPR #12を作成： https://github.com/jphacks/os_2604/pull/12 。マージは未実施。
- 最新取得main `444390f` と `.codex/STATE.md`、onboarding_screen.dart、result_screen.dart、scan_screen.dartで競合。GitHubもCONFLICTINGを確認。作業ファイルのマージは行っていない。
- UI should 2件と競合をPR本文に明記。次はmainのUIを保持してモード切替を統合し、UI指摘を修正後に再検証する。今回は既存変更をレビュー可能なPRとして提出する範囲で完了。
- 検証は実装コミットでの整形・解析・全279テスト成功。今回のPR提出では製品コードを変更していない。

## 2026-10-18 心拍推定ブランチの未コミット分をコミット

- ユーザー依頼：心拍推定ブランチの未コミット分をコミットする。対象は `rppg_accuracy_validation_integration`、基点 `315cf61`。通常／研究モード切替、schema v5移行、テスト、接続・検証・Aレビュー文書を1コミットにまとめる。push・PR・main統合は今回の依頼外。
- コミット前の再検証：整形75ファイル差分なし、flutter analyze --no-pub指摘なし、flutter test --no-pub全279件成功、git diff --check成功。ログ `/private/tmp/rppg-precommit-{format,analyze,tests}.log`。製品コード・テストは既存の未コミット内容から変更していない。
- Aレビューのshould 2（開始ボタンの見切れ、状態案内）は未修正。今回は既存変更のコミット依頼のため修正を追加せず、次のUI修正へ引き継ぐ。最終UI承認は保留。詳細は `docs/a-ui-review.md`。
- 別依頼でmain `444390f` をiPhone 17へ署名付きReleaseで上書きインストール・起動済み。本コミット対象の切替・v5版を今回再インストールしていない。下記の実機結果は過去の切替版検証として扱う。
- 元チェックアウトのLED実装の未コミット変更は保持し、本コミットには含めない。mainの後続変更は未取り込み。

## 以下はコミット前の実装・レビュー記録

## 2026-10-18 A視点の最終UIレビュー

- ユーザー依頼：Aの最終UIレビュー。対象は引き続き心拍推定ブランチ315cf61＋前工程の未コミット差分。製品UI・実機・健康記録は変更せず、コードと架空データの描画でレビュー。
- レビュー票：docs/a-ui-review.md。blocker 0、should 2（開始ボタンの初期表示見切れ、未開始／保存失敗時の状態案内の不整合）、nice 1（拡大時の結果ラベル配置）。レビュー実施済み、should未修正のため最終UI承認は保留。
- 描画検証：393×852/100%と320×568/200%、初回説明・ホーム・撮影・通常/研究結果・履歴・設定・権限拒否・中断・保存失敗の20条件＋iPhone17相当402×874（上62/下34）の撮影1条件成功。開始文字y836〜856に対しSafeArea上端840で見切れを再現。表示中のタップ領域・ラベルに指摘なし、結果入力操作もスクロール後に確認。コントラストのピクセル警告は解決済み色の比率で誤検出を切り分けた。
- ログ/private/tmp/a-ui-review-complete.log、ハーネス/private/tmp/a_ui_review_test.dart。証跡は/Users/shindenfuta/.codex/visualizations/2026/10/17/01a14b3e-6941-70e0-9aa1-09f1f9bd6cf4/a-ui-review。全て架空データ。実機の顔・健康値は取得していない。前工程の279テストは再実行せず、今回の21条件と区別する。
- Device Interactionスキルのサブエージェント指示に従い、ネイティブ下部バーを独立確認。SwiftUI専用iPhone17/iOS27 Simulatorホストで通常/最大文字の見切れなし。UIテスト1件成功：3ラベル・タップ切替・選択trait・各93.33×76ptを確認。ホスト停止、MCP設定復帰済み。Reduce Motionは静的確認のみ。実アプリの実機VoiceOver合格ではない。
- 今回追加はレビュー票とSTATE等の状況文書のみ。製品lib/test、iPhone上の通常版、DBは変更していない。commit/push/PRなし。
- 次：A01/A02修正→撮影画面再検証→iPhone17で最終確認。A03は任意。通常版は前工程の復帰済み状態を維持。

## 以下は前工程の実装・実機確認

## 2026-10-18 C担当・通常／研究モード切替

- ユーザー決定：通常／研究の切替を設ける。対象は心拍推定ブランチ。開発フェーズはDay 1とDay 2の間。
- 作業場所：/Users/shindenfuta/.gemini/antigravity/worktrees/os_2604/rppg_accuracy_validation_integration。ブランチ同名、HEAD 315cf61。git ls-remoteでリモート心拍ブランチも315cf61と照合。remote mainは444390fで未取り込み。新UIは今回のA観点レビュー実施済みだが、should 2のため最終承認は保留。
- 作業開始時はこのworktreeはclean。今回の変更は未コミット。commit・push・PR・mergeは未依頼のため未実施。
- 元の /Users/shindenfuta/os_2604 は codex/e84-led-notification。LEDの既存未コミット変更を保持。資料の作業案を一時作成したが、今回の対象へ移し、元側は今回の資料差分だけ元に戻した。LED版を心拍版へ統合していない。

## 実装

- ScanScreenに研究スイッチ。画面を開くたび通常（オフ）。開始前のみ選択し、開始後・失敗再試行中・保存中は変更不可。設定自体は永続化しない。
- main.dartは通常用day1Trialと研究用day1Experimentalを分け、app.dart経由で注入。切替時は旧サービスを取消・解放して新規生成。切替中の開始を禁止し、離脱後に新セッションを作らない。
- 共通ScanModeはstandard/research/legacyUnknown。Cが成功結果にモードを付け、Bが即保存・追記・レポート・履歴詳細で維持。通常は実験処理を停止し心拍・顔色null、研究は推定不能でも研究モードを保持。
- DB schema v5：scan_mode列追加、既存はlegacyUnknown。既存の日時・推定値・出典・NULL・入力・本文・生成モード・説明確認・通知設定を保持。旧v2/v3の合意済み日時変換も維持。from<2では新テーブル生成に列を含むため重複追加しない。移行は既存transaction内。
- v5移行後は旧LED版(v4)への単純差戻し不可。戻す場合はLED側にもv5対応が必要。DB削除やアプリのアンインストールで回避しない。
- 初回説明・撮影前・結果・新生成レポートにモード／研究制約。rPPG出典と外部由来を区別。心拍の品質不足非表示を維持。
- 15秒時計・撮影品質閾値・P2推定アルゴリズム・AIチャネル・AI10秒期限・比較条件・権限・依存は変更なし。ネイティブ設定の変更なし。

## 変更ファイル

- lib/app.dart、main.dart、models/health_check_result.dart、features/scan/health_scan_controller.dart。
- lib/screens/{scan,result,onboarding}_screen.dart、services/ai/template_record_summary.dart。foundation_models_client.dartは古い「Swift未接続」コメントだけ訂正。
- lib/services/db/{app_database.dart,app_database.g.dart,health_record_repository.dart}。Drift生成は既存build_runnerで実施。
- test/screens/research_mode_test.dart、test/services/db/scan_mode_migration_test.dartを追加。既存health_scan_controller_testとlegacy_timestamp_migration_testを更新。
- README、docs/{implementation-decisions,c-integration,c-integration-status,c-ai-integration,demo-guide}.md更新、docs/c-validation.md追加。このSTATEを更新。

## 検証

- 整形確認：75ファイル変更なし。flutter analyze --no-pub：指摘なし。
- flutter test --no-pub：全279件成功。ログ /private/tmp/c-research-tests-final.log。切替・処理中の変更禁止・切替中の離脱・既定通常への復帰・研究nullの保存・追記／定型文での保持、v4→v5→再openで全項目保持と旧日時移行を確認。
- 元のLEDチェックアウトも調査開始時に整形78ファイル・解析・全287テストが成功したが、今回の心拍版の結果と混同しない。
- sandbox内のFlutter testはlocalhostソケット拒否で失敗し、実行環境を変更して同じ試験を実行し成功。devicectlもsandboxではCoreDevice初期化timeout、読取を再実行してphysical iPhone 17 / iOS 27.0.1の有線接続を確認。
- iOS Releaseビルド成功（60.5MB）。最初はCocoaPodsのbinがPATHになく失敗し、導入済みbinを追加して成功。ログ /private/tmp/c-research-release-build-retry.log。既存署名・登録済みiPhoneを使った署名付きXcodeビルドも成功。ログ /private/tmp/c-research-signed-build.log。新しい証明書／端末登録やtracked Team固定なし。
- codesign --verify --deep --strict成功。sandbox内ではCSSMERR_TP_NOT_TRUSTEDとなり、同じ成果物を通常の信頼サービスを使う環境で再検証して成功。
- physical iPhone 17 / iOS 27.0.1の既存com.example.os2604へ更新インストール・起動成功。アンインストール／健康記録削除なし。ログ /private/tmp/c-research-{install,launch}.json。署名付き成果物 /private/tmp/c-research-derived-data/Build/Products/Release-iphoneos/Runner.app。
- 2026-10-18、ユーザーが確認依頼全体に「なっている」と回答。通常で15秒計測後、心拍・顔色が未測定／通常モード、研究で計測後、研究モードと注意文、研究記録のレポートが端末内AIで作成、更新前履歴の保持と旧記録のモード未記録表示を確認。顔画像・測定値は取得していない。続いてユーザーが再起動後も「記録は残っています」と回答。記録保持は確認済み。レポート本文の保持・本文詳細は個別には未明示で、Aの最終レビューも未確認。

## 過去の実機根拠と残り

- HEAD 315cf61の旧STATEに、2026-10-17のiPhone 17 / iOS 27.0.1で15秒計測・即保存・レポートとApple Watch同時比較1回の記録あり。個人の測定実数値を転記しない。1回を精度保証にしない。
- 同日のAI／利用不可時定型文・オフライン等の確認記録があるが、今回の切替・v5版の合格へ読み替えない。
- 現在：通常／研究計測・通常AI・旧履歴・再起動後の記録保持はユーザー確認済み。AI利用不可応答の注入版で定型文と理由、新規記録と定型レポート本文の再起動後保持も「確認できました」と回答。C04は注入試験の合格として記録。OSでの実際のAI利用不可・生成例外／timeoutとは区別する。
- 2026-10-18、通常版の署名を再検証し、同bundleへ更新復帰・起動成功。現在iPhoneは通常版。ログ/private/tmp/c-normal-restored-{install,launch}.json。通常版は注入前に通常AIを確認した同じ署名済み成果物で、復帰後の追加AI再生成は行っていない。記録削除・アンインストール・OS設定変更なし。
- ホストのFLUTTER_TARGETもlib/main.dartに復帰し通常Release再ビルド成功（60.5MB、/private/tmp/c-normal-restore-build.log）。検証用entrypointは製品mainへ入れていない。
- 残り：A観点レビューのshould 2修正と最終承認、確定画面からの発表素材。C05顔外れ／離脱・C06研究信号不足・C07オフライン2回は今回版の手動再試験未実施（既存の自動確認／過去版の実機結果と区別）。AIレポート本文の再起動後保持・本文詳細も個別には未明示。Cの制約説明・接続資料は更新済み。追加精度検証を必須作業へ繰り上げない。
- Android/Gemini Nano完成、追加精度検証、HealthKit/Health Connect、クラウド同期、失敗保存画面、ストア公開準備は今回の必須外。

## コマンド環境

Flutter /private/tmp/os2604-c-flutter (3.47.7 / Dart 3.13.5)、PUB_CACHE=/private/tmp/os2604-c-dart/pub-cache、XDG_CONFIG_HOME=/private/tmp/os2604-c-config。CocoaPodsは/private/tmp/os2604-c-gems/binをPATHへ追加しGEM_HOME/GEM_PATH同prefix、RUBYOPT=-rlogger。tool/flutter_with_xcode.shでXcodeをコマンド単位で指定。システムxcode-selectは変更していない。

## AI利用不可の注入試験（完了・通常版へ復帰済み）

- 生成スクリプト/private/tmp/prepare-c-ai-unavailable.py、entrypoint/private/tmp/c-ai-unavailable-entry.dart。現在のmain.dartを基に相対importをpackage importへ直し、AIクライアントだけunavailable応答へ差し替え、上部に検証専用を常時表示。計測・DB・レポートUIは通常実装を使用し、測定のモックは使わない。生成APIへは進めない。
- 検証専用のRelease・署名付きビルド・署名検証・同bundle更新導入・起動成功。成果物/private/tmp/c-ai-unavailable-derived-data/Build/Products/Release-iphoneos/Runner.app。ログ/private/tmp/c-ai-unavailable-{build,signed-build}.log、{install,launch}.json。
- ユーザーが新しい通常モード記録の計測→定型文と理由→再起動後の記録・本文保持を2点とも確認。過去AI本文を上書きする手順は案内していない。
- 通常版の復帰用成果物/private/tmp/c-research-derived-data/Build/Products/Release-iphoneos/Runner.appの署名再検証、同bundle更新導入、起動成功。現在iPhoneは通常版。検証専用版を残した状態ではない。
- OSの実際のAI利用不可・MethodChannel失敗・生成例外／timeoutの実機再現ではない。これらの分岐は既存の自動試験で確認済み。
