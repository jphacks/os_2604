#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d /tmp/e84-env-test.XXXXXX)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM
cc -std=c11 -Wall -Wextra -Werror -Ithird_party/sensirion tests/driver_test.c third_party/sensirion/sht4x_i2c.c third_party/sensirion/sensirion_i2c.c third_party/sensirion/sensirion_common.c -o "$test_dir/driver"
"$test_dir/driver"
cc -std=c11 -Wall -Wextra -Werror -Itests/stubs -Ithird_party/sensirion tests/hal_test.c third_party/infineon/sensirion_i2c_hal.c -o "$test_dir/hal"
"$test_dir/hal"
echo 'SHT40 CRC / read / write / full-width HAL error tests passed.'
