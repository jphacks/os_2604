# C担当：AI利用可否と失敗時処理の準備

## 実装範囲

2026-10-17、ユーザーの依頼でDart側の利用可否・失敗時処理を実装した。共有のHealthCheckResult・計測API・DB・pubspec・ios/は変更していない。以下はC内部の実行部品と、Bへ共有するネイティブ接続案である。共有のHealthReport／createReport、比較・保存・再生成の製品契約を確定するものではない。

| ファイル | 責務 |
| --- | --- |
| `lib/services/ai/on_device_ai_client.dart` | 利用可否・失敗理由と端末内クライアント境界 |
| `lib/services/ai/foundation_models_client.dart` | 未接続のMethodChannelを含むDart側アダプター |
| `lib/services/ai/on_device_ai_runner.dart` | 利用可否確認、短文選択、期限、定型文、二重要求・キャンセル制御 |
| `lib/services/ai/template_record_summary.dart` | 現在記録の文章化。生成モードを除く本文の合成にも対応 |

Swiftの実装・チャネル登録と実機確認は未実施。今のアプリにネイティブ接続がなければ、端末を非対応と断定せず `bridgeUnavailable` で定型文へ切り替える。クラウドAI・モデルの自動取得は追加していない。

## Dart側の使い方

```dart
final runner = OnDeviceAiRunner(
  client: const FoundationModelsClient(),
  timeout: approvedAiTimeout, // Duration。秒数はB/C・人間の未決事項。
);

// Bが結果を保存し終えた後に呼び出す。
final outcome = await runner.generateReflection(savedScan);
// outcome.text / outcome.mode / outcome.fallbackReason
// Bは削除・入力更新・再生成による世代変更を確認してから既存IDへ追記する。

// 生成中の離脱・削除・入力変更など。
runner.cancel();
// 所有者の破棄時。
runner.dispose();
```

`AiTextOutcome` はC内部の文章実行結果で、生成日時や比較情報は持たない。B/Cの保存用HealthReportが決まったら変換する。例中の `approvedAiTimeout`・`savedScan` は統合側が渡す値。保存処理やその成功をこの部品は代行・判断しない。

### 利用可否と失敗

- 利用可否はリクエストごとに確認し、利用可能な場合だけ生成へ進む。
- 非対応・無効・モデル未準備・初期化中・制限・ブリッジ未接続・その他利用不可は、理由を区別して定型文へ戻す。
- 利用可否の例外と生成中の例外を区別する。空・未知・不適切な応答も定型文へ戻す。ネイティブの例外文、入力、スタックはUI用文章へ出さず、ログも追加していない。
- タイムアウトは利用可否確認から生成までの合計待ち時間。正のDurationを必須指定し、製品用の秒数を既定値にしていない。テストの2秒は合成検証用。
- 同じrunnerで同時に複数のネイティブ処理を起動しない。次の要求は `busy` を理由とする定型文を返す。AIが正常に使えなかった場合の実際のモードは常に `template`。
- 品質不十分・中断の記録はAIへ渡さず、現在記録の定型文を返す。

### キャンセル・遅い応答

キャンセル／破棄／タイムアウト時は、呼び出し元へ定型文を返して待ち時間を終える。生成を始めていればrequestIdを指定してネイティブへキャンセルを依頼する。キャンセルの失敗もUIへ例外として流さない。

この時点ではネイティブの停止を保証できない。`isNativeBusy` は元のネイティブFutureが完了するまでtrueを維持し、キャンセル応答だけを受け取っても次の生成を起動しない。元の処理が終了しなければ、その間は定型文で継続する。同じクライアントへ別runnerを追加して制限を迂回しない。

遅い成功・例外は処理済みの結果を書き換えない。生成完了済みの結果について、DBへ更新してよいかはBが判断する。Bは削除済みIDをupsertで復活させず、入力や生成世代が変わった応答を書き込まない。

## AI応答の扱い

今回はAIの自由文をそのまま表示せず、現在記録に適用できる次のキーの一つを選ぶ方式に限定した。未知のキー、説明文、数字や病名を含む任意の文章は採用しない。Dartで記録内容と固定文を組み立てる。

| キー | 適用条件 | 表示する補足 |
| --- | --- | --- |
| `reviewRecord` | 有効記録 | 記録した内容を振り返ってください。 |
| `reviewSelfCondition` | 自己申告あり | 自己申告の体調も、記録を振り返る手がかりになります。 |
| `reviewTemperature` | 外部由来の体温あり | 体温は表示された出典と合わせて振り返ってください。 |

成功時は `onDevice` とし、本文にも「端末内AI（短文選択）」と明示する。現在記録の数値・出典はDartが表示し、AIから数値を受け取らない。プロンプトへ保存用ID・既存レポート・実体温・顔画像は渡さず、自己申告と項目の有無・選択可能キーだけを渡す。

履歴比較の文章は未実装。Bの集計結果と共有レポートAPIが決まった後に接続する。

## ネイティブ側へ提案するチャネル

チャネル名：`jp.jphacks.os_2604/on_device_ai`。以下は**アプリ独自の通信形式**であり、AppleのAPI名・全エラー列挙を表していない。Bが管理するSwift登録・iOS設定への変更対象として共有し、採用時に合わせる。

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

文字列以外の戻り値は不正な応答として扱う。`MissingPluginException` はブリッジ未接続。生成用FlutterErrorのcode案は `unsupported / disabled / modelNotReady / initializing / restricted / rateLimited / refused / timeout / cancelled`。未知のエラーは利用可否確認ならavailabilityCheckFailed、生成ならgenerationFailedへ戻す。自由形式のエラー文を表示用に使用しない。

ネイティブ側は、requestIdごとにTaskとFlutter結果コールバックを管理する。キャンセル時も元の生成Futureが終了するようにし、同じ結果コールバックを二重に呼ばない。利用可否確認とモデル生成は端末内のみ。モデル・言語・地域・制限の確認結果が出るまでは利用可能と返さない。

## Apple APIの確認

2026-10-17に公式資料を読み、ローカルXcode 27のFoundationModels.swiftinterfaceでも型名を照合した。Swift実装のコンパイルやAI実行はまだ行っていない。

- [SystemLanguageModel.Availability](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum) で利用可否を確認する。
- [UnavailableReason](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason) の公開理由は `deviceNotEligible / appleIntelligenceNotEnabled / modelNotReady`。上記のinitializing・restrictedはアプリ側の通信区分。
- iOS 27では [LanguageModelError](https://developer.apple.com/documentation/foundationmodels/languagemodelerror) にrateLimited・refusal・timeout等がある。iOS 26の [LanguageModelSession.GenerationError](https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror) と分けて扱う。Bが使用するSDKが27未満なら、27専用型を直接参照する前にSDK更新方針を確認する。

正式対象はiPhone 17 / iOS 27以降だが、BのDeployment Targetと使用SDKは別に確認する。機種名・OSバージョンだけでApple Intelligence有効・モデル準備済みと判定しない。

## 検証結果と残り

一時Flutter環境で静的解析は指摘なし、全121テスト成功（既存66＋実行管理30＋チャネル25）。端末非対応・未準備・初期化中・制限・チャネル欠落・不正な応答・例外・タイムアウト・二重要求・キャンセル失敗・遅い応答・破棄を合成入力と偽のネイティブ応答で検証した。新しい依存追加はない。

残りは、Bとの共有レポートAPI・タイムアウト秒数、Swiftブリッジ登録、正確なOS・Apple Intelligence設定・モデル準備・実際の生成、保存後の追記と削除競合の統合確認。実機でのAI成功やオフライン動作の合格はまだ報告できない。
