# E84用ファームウェア

この節は復旧用の既存LEDファームウェアの手順。室温・湿度用の独自GATT拡張は [environment/README.md](environment/README.md) を参照。環境拡張はビルド・実機書き込み照合が成功し、実取得の表示を確認中。AI推論は追加しない。[公式Find Me v2.3.1](https://github.com/Infineon/mtb-example-psoc-edge-btstack-findme/tree/ea2a19fa2b1321525f3ae0645ae2fba4f5d64340) を使用する。採用元は `findme-source.json` に固定した。2026-10-18、BSP付きプロジェクトの生成・ビルド・キットへの書き込みと照合に成功。AIROCからHigh Alert／No Alertで点灯・消灯できたとユーザーが報告。健康チェックアプリとの連動試験は未完了。

## 環境を準備する

公式READMEの条件はModusToolbox 3.7以上（v2.3.1では3.8で試験）、BSP 1.0.0以上、GCC ARM 14.2.1。実際に使うツールとBSPの版、基板リビジョンを記録する。

[公式のプロジェクト作成手順](https://github.com/Infineon/mtb-example-psoc-edge-btstack-findme/blob/ea2a19fa2b1321525f3ae0645ae2fba4f5d64340/docs/using_the_code_example.md) に従う。今回成功したCLI手順は、先に固定版ソースを取得し、Project Creatorの取り込み機能で **KIT_PSE84_AI** を組み合わせる方法。

```sh
git clone --depth 1 --branch release-v2.3.1 https://github.com/Infineon/mtb-example-psoc-edge-btstack-findme.git E84FindMeSource
git -C E84FindMeSource rev-parse HEAD
mkdir -p e84-firmware-work
/Applications/ModusToolbox/tools_3.8/project-creator/project-creator-cli \
  --board-id KIT_PSE84_AI --app-path "$PWD/E84FindMeSource" \
  --user-app-name E84LedDemo --target-dir "$PWD/e84-firmware-work"
```

取り込み前のHEADが `ea2a19fa2b1321525f3ae0645ae2fba4f5d64340` と一致することを確認する。取り込み後はProject Creatorが設定と依存を更新するため、生成プロジェクトのHEADだけで元版を判定しない。今回、IASを実装する `proj_cm33_ns/source/main.c` は元ソースと一致した。BSPは1.4.0（4894dd6）、生成ターゲット名は `APP_KIT_PSE84_AI`。依存版と成果物のSHA256は `build-manifest.json` に記録した。依存が変わった場合はこの検証結果を流用しない。

使用ツールはTools 3.8.0.18384、Programming tools 1.9.0.2261、GCC 14.2.1.331、Edge Protect 2.3.0.958。ユーザーが各EULA・導入範囲に同意後、公式配布物のハッシュ・署名・公証を照合して導入した。

## ビルドと書き込み

Project Creatorが生成したプロジェクトのルートで実行する。生成済み `common.mk` の `TARGET=APP_KIT_PSE84_AI` を使う。元サンプルの既定ターゲットや、生成前の `KIT_PSE84_AI` を上書き指定しない。GCCのパスは実際の導入先に合わせる。

```sh
cd e84-firmware-work/E84LedDemo
make build TOOLCHAIN=GCC_ARM CY_COMPILER_PATH="$HOME/Applications/mtb-gcc-arm-eabi/14.2.1/gcc"
# キットをKitProg3 USB端子で接続してから実行。現在のファームウェアを書き換える。
make program TOOLCHAIN=GCC_ARM CY_COMPILER_PATH="$HOME/Applications/mtb-gcc-arm-eabi/14.2.1/gcc"
```

今回の生成先は `/private/tmp/e84-firmware-work/E84LedDemo`。ビルド・書き込みとも終了コード0で成功し、OpenOCDの `verified 268692 bytes` を確認した。通常のflash書き込み・照合・再起動を使用し、eFuseやライフサイクル変更は実行していない。既存KitProg3 2.80.1529には更新警告が出たが、書き込みと照合は成功したため更新していない。成果物はGit対象外の `build/e84/app_combined.hex` にも保管。

## キット単体の受け入れ

1. 給電後、広告中のUSER_LED2を確認。広告名は `Find Me Target`。未接続では約120秒で広告が止まるため、必要ならキットをリセットする。
2. iPhoneに公式の[AIROC Bluetooth Connect（App Store）](https://apps.apple.com/jp/app/airoc-bluetooth-connect-app/id6443702288)を導入する（Infineon Technologies AG、無料）。Bluetooth利用を許可し、アプリ内から明示的に対象を選ぶ。
3. Find Me ProfileのNo AlertでUSER_LED1消灯、High Alertで点灯することを目視確認。IASは `1802`、Alert Levelは `2A06`、Write Without Responseで `[0x00]`／`[0x02]`。
4. 切断時の消灯と再広告を実機で確認し、AIROCから切断してからFlutterアプリへ接続する。

固定版の `proj_cm33_ns/source/main.c` は切断時にIAS LEDを消灯し、広告を再開する実装。ただし基板での動作は未確認。独立したキット側3秒タイマーは追加していない。

アプリ側の操作・L01〜L12は [LEDデモ手順](../../docs/e84-led-demo.md) を参照。
