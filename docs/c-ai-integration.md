# C担当：端末内AI接続と定型文フォールバック

## 実装範囲

2026-10-18更新。Dartの利用可否・失敗処理、Swift Foundation Modelsブリッジ、Bの結果・比較・保存へ接続済み。過去の「AI未接続」は解消。対象と実機確認の範囲は[B・C接続状況](c-integration-status.md)を参照。

| ファイル | 責務 |
| --- | --- |
| `on_device_ai_client.dart` | 利用可否・失敗理由とクライアント境界 |
| `foundation_models_client.dart` | 登録済みSwiftブリッジとのMethodChannel通信 |
| `on_device_ai_runner.dart` | 利用可否、短文選択、期限、定型文、二重要求・取消 |
| `template_record_summary.dart` | 記録・計測モード・Dart集計値の文章化 |

2026-10-17のiPhone 17 / iOS 27.0.1で通常AIと利用不可時の定型文をユーザー確認済み。今回の切替追加版の再試験とは区別する。接続欠落は `bridgeUnavailable` として定型文へ切り替える。クラウドAIやアプリによるモデル自動取得は追加していない。

## Dart側の使い方

```dart
final runner = OnDeviceAiRunner(
  client: const FoundationModelsClient(),
  timeout: const Duration(seconds: 10), // 現在のmain.dartと同じ。
);

// Bが結果を保存し終えた後に呼び出す。
final outcome = await runner.generateReflection(savedScan, baseline: baseline);
// outcome.text / outcome.mode / outcome.fallbackReason
// Bは削除・入力更新・再生成による世代変更を確認してから既存IDへ追記する。

// 生成中の離脱・削除・入力変更など。
runner.cancel();
// 所有者の破棄時。
runner.dispose();
```

`AiTextOutcome` は本文・実際のモード・理由を返す内部型。Bの `ResultScreen` が保存済み記録とDartの `baseline` を渡し、削除・入力更新・生成世代を確認して同じIDへ本文と生成モードを保存する。runnerは保存を代行・判断しない。

### 利用可否と失敗

- 利用可否はリクエストごとに確認し、利用可能な場合だけ生成へ進む。
- 非対応・無効・モデル未準備・初期化中・制限・ブリッジ未接続・その他利用不可は、理由を区別して定型文へ戻す。
- 利用可否の例外と生成中の例外を区別する。空・未知・不適切な応答も定型文へ戻す。ネイティブの例外文、入力、スタックはUI用文章へ出さず、ログも追加していない。
- タイムアウトは利用可否確認から生成までの合計待ち時間。正のDurationを必須指定し、現在のアプリは10秒を渡す。計測の15秒には含めない。テストの2秒は合成検証用。
- 同じrunnerで同時に複数のネイティブ処理を起動しない。次の要求は `busy` を理由とする定型文を返す。AIが正常に使えなかった場合の実際のモードは常に `template`。
- 品質不十分・中断の記録はAIへ渡さず、現在記録の定型文を返す。

### キャンセル・遅い応答

キャンセル／破棄／タイムアウト時は、呼び出し元へ定型文を返して待ち時間を終える。生成を始めていればrequestIdを指定してネイティブへキャンセルを依頼する。キャンセルの失敗もUIへ例外として流さない。

SwiftはTask取消と元要求の完了を実装済みだが、Dartはネイティブの停止を前提にしない。`isNativeBusy` は元のネイティブFutureが完了するまでtrueを維持し、キャンセル応答だけを受け取っても次の生成を起動しない。元の処理が終了しなければ、その間は定型文で継続する。同じクライアントへ別runnerを追加して制限を迂回しない。

遅い成功・例外は処理済みの結果を書き換えない。生成完了済みの結果について、DBへ更新してよいかはBが判断する。Bは削除済みIDをupsertで復活させず、入力や生成世代が変わった応答を書き込まない。

## AI応答の扱い

今回はAIの自由文をそのまま表示せず、現在記録に適用できる次のキーの一つを選ぶ方式に限定した。未知のキー、説明文、数字や病名を含む任意の文章は採用しない。Dartで記録内容と固定文を組み立てる。

| キー | 適用条件 | 表示する補足 |
| --- | --- | --- |
| `reviewRecord` | 有効記録 | 記録した内容を振り返ってください。 |
| `reviewSelfCondition` | 自己申告あり | 自己申告の体調も、記録を振り返る手がかりになります。 |
| `reviewTemperature` | 外部由来の体温あり | 体温は表示された出典と合わせて振り返ってください。 |
| `reviewHistoryComparison` | 直近7日間の基準値あり（有効記録3件以上かつ体調3件以上） | 直近7日間の記録との差も、日々の振り返りに役立ててください。 |

成功時は `onDevice` とし、本文にも「端末内AI（短文選択）」と明示する。現在記録の数値・出典はDartが表示し、AIから数値を受け取らない。プロンプトへ保存用ID・既存レポート・実体温・顔画像は渡さず、自己申告と項目の有無・直近7日間の基準値集計・選択可能キーだけを渡す。

過去比較は `HistoryBaseline`（今日を除く直近7暦日の有効記録3件以上・体調入力3件以上で中央値を算出、不足時は「基準値蓄積中」）をDart側で計算し、`OnDeviceAiRunner.generateReflection(scan, baseline: baseline)` と `TemplateRecordSummary` の両方へ接続済み。

## ネイティブ側チャネル実装（`ios/Runner/AppDelegate.swift`）

チャネル名：`jp.jphacks.os_2604/on_device_ai`。`AppDelegate.didInitializeImplicitFlutterEngine` で `OnDeviceAiBridge` を登録済み。

| メソッド | 引数 | 正常な戻り値 |
| --- | --- | --- |
| `availability` | なし | 下記の文字列 |
| `generateReflection` | requestId / instructions / prompt | 選択したキー文字列一つ |
| `cancelGeneration` | requestId | null。元の生成要求も必ず一度だけ完了させる |

利用可否の文字列とDartへの変換：

| チャネルの値 | Dart側 |
| --- | --- |
| `available` | available |
| `deviceNotEligible` | unsupported |
| `appleIntelligenceNotEnabled` | disabled |
| `modelNotReady` | modelNotReady |
| `initializing` | initializing（アプリ側の初期化状態） |
| `restricted` | restricted（アプリ側で区別する制限状態） |
| `unavailable`、将来の未知の値 | unavailable |

文字列以外の戻り値は不正な応答として扱う。`MissingPluginException` はブリッジ未接続。生成用FlutterErrorのcodeは `unsupported / disabled / modelNotReady / initializing / restricted / rateLimited / refused / timeout / cancelled`。未知のエラーは利用可否確認ならavailabilityCheckFailed、生成ならgenerationFailedへ戻す。自由形式のエラー文を表示用に使用しない。

ネイティブ側は、requestIdごとにTaskと単発完了ラッパー（`PendingGeneration`）を管理する。キャンセル時も元の生成Futureが終了するようにし、同じ結果コールバックを二重に呼ばない。利用可否確認とモデル生成は端末内のみ。モデル・言語・地域・制限の確認結果が出るまでは利用可能と返さない。

## Apple APIの確認

2026-10-17に公式資料を読み、ローカルXcode 27のFoundationModels.swiftinterfaceで型名を照合し、`ios/Runner/AppDelegate.swift` に実装した。

- [SystemLanguageModel.Availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum) で利用可否を確認する。
- [UnavailableReason](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason) の公開理由は `deviceNotEligible / appleIntelligenceNotEnabled / modelNotReady`。上記のinitializing・restrictedはアプリ側の通信区分。
- iOS 27では [LanguageModelError](https://developer.apple.com/documentation/foundationmodels/languagemodelerror) にrateLimited・refusal・timeout等がある。iOS 26の [LanguageModelSession.GenerationError](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror) と分けて扱う。

## 検証結果と残り

- 利用不可・例外・不正応答・timeout・取消・遅い応答の破棄・過去比較は自動テストで確認。最新の全体結果は `.codex/STATE.md` に記録する。
- 2026-10-17の実機で通常AI・利用不可時の定型文・オフライン・手動UIをユーザー確認済み。
- 2026-10-18、今回の切替・schema v5版で研究記録の生成と「端末内AIで作成」をユーザー確認済み。AI利用不可応答を注入した専用版では、定型文・理由表示と再起動後の記録／定型レポート本文保持をユーザー確認済み。確認後は通常版へ復帰・起動済み。OS側の実際の利用不可やAIレポート本文の再起動後保持は個別には未確認。[C確認票](c-validation.md)を参照。
- AIオフと生成例外／timeoutは別の条件。生成例外／遅延の実機再現は未確認。自動試験を実機合格へ読み替えない。
