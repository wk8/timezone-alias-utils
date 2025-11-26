#!/usr/bin/env bash

set -euo pipefail

cd /usr/share/zoneinfo

readlink -f "$BASE_TEST_TZ_NAME"
readlink -f another/weirdtz
