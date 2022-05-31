#!/usr/bin/env bash

set -x
set -e
set -f
set -u
set -o pipefail

SOURCING=1
. ./freekazna.sh

trap 'echo $?' EXIT

echo "$CURRENCY_SIGN"
test "$(_mcc2description 4816)" = "Computer Network Services"
test "$(_string2md5 fff)" = "8b8a8b353298f798e3eb8628661617b6"
_check_bank_is_supported avangard
! _check_bank_is_supported novokukuevobank

test "$(_date2unix__avangard '26.02.2022 20:20')" = 1645896000
test "$(_sum2integer__avangard '123.45')" = 12345
test "$(_line2format__avangard "$(head -n 1 test-data/avangard.csv)")" = "5d23fa9895e0ff5af1557d49d5cab1ca;1645896000;14500;5912"
#_file2db__avangard test-data/avangard.csv
