# E84 SHT40環境拡張

2026-10-18時点：ビルド・ホスト上のドライバーテスト成功。その後のユーザー依頼で、キットへ書込・271664 bytes照合・CYBOOT_SUCCESSを確認し、iPhoneにも環境対応版を導入。ユーザーがiPhone上の室温・相対湿度の実値表示を確認。計測後保存・LED共存の試験は進行中。

Find Me v2.3.1のIASと広告名を維持し、別のRead専用GATTを追加する。専用UUID・通信契約・固定ドライバー版は `../environment-protocol.json`。約2秒ごとにFreeRTOSタスクが高精度単発取得し、CRC／I²C／範囲検査を通ったペアだけを公開する。Read時は排他制御したキャッシュをシリアライズし、I²C待機・ヒーター・数値ログは使わない。失敗後に前回値を正常値として返さない。

## 再現

[親の手順](../README.md)で固定Find Meソースと同じBSP 1.4.0／生成TARGET `APP_KIT_PSE84_AI` の新しいプロジェクトを作る。復旧用LEDプロジェクトは保持する。

```sh
python3 firmware/e84/environment/apply.py /absolute/path/to/E84EnvironmentDemo
make -C /absolute/path/to/E84EnvironmentDemo build TOOLCHAIN=GCC_ARM CY_COMPILER_PATH=/absolute/path/to/gcc
sh firmware/e84/environment/tests/run.sh
```

`apply.py` は元のmain.c／GATT生成物のSHA256を照合してからパッチと固定ドライバーを配置する。二重適用・別のベースは拒否する。GATT生成物の変更は `findme-environment.patch` が正本。この状態でBluetooth Configuratorから再生成すると消えるため、再生成した場合はパッチを見直し、アプリとのUUID・ハンドル・Read属性を再試験する。

Infineon SHT4xライブラリとSensirion依存を必要なファイルだけ同梱し、元の著作権表示・LICENSE／EULAを保持する。Infineonの `sensirion_i2c_hal.c` のみローカル修正がある：32bitのHAL戻り値をint8へ直接切り詰めず、成功0／失敗−1へ正規化する。下位8bitが0のエラーを成功として扱わない。ホスト試験は本物のCRC処理とI²C失敗、およびこの正規化を合成入力で検証する。ボード上でのI²C疎通を代替しない。

今回の生成先は `/private/tmp/e84-firmware-work/E84EnvironmentDemo`。成果物は `build/e84/environment/app_combined.hex`（Git対象外）。SHA256・ツール・依存・検証範囲は `../environment-build-manifest.json`。

## 後続の実機導入と復旧

実機確認の追加依頼で下記の通常書き込みを実施した。再導入する場合はKitProg3 USB接続、AIROC等の接続解除、アプリと通信契約の一致を確認して `make program` を使う。eFuse／ライフサイクル／デバッガーファームウェアは変更しない。実取得、異常時にもIASが動くこと、1接続でのReadとLED、切断時の消灯を確認する。

復旧時は元の `/private/tmp/e84-firmware-work/E84LedDemo` を `make program` するか、既存 `build/e84/app_combined.hex` を通常のflash書き込みで使用する。元版へ戻した後も、アプリはLEDを維持し、環境情報を「未対応」と表示する。アプリのDBはv7へ進むため、復旧用LEDファームウェアと、古いv4アプリへのダウングレードを混同しない。
