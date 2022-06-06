#!/usr/bin/env bash

set -x
set -e
set -f
set -u
set -o pipefail

SOURCING=1
. ./freekazna.sh

TMP="$(mktemp -d)"
trap 'rc=$?; rm -fvr "$TMP"; echo "$rc"' EXIT

echo "$CURRENCY_SIGN"
test "$(_mcc2description 4816)" = "Computer Network Services"
test "$(_string2md5 fff)" = "8b8a8b353298f798e3eb8628661617b6"
_check_bank_is_supported avangard
_check_bank_is_supported raiffeisenrus
_check_bank_is_supported tinkoff
! _check_bank_is_supported novokukuevobank

test "$(_date2unix__avangard '26.02.2022 20:20')" = 1645896000
test "$(_sum2integer__avangard '123.45')" = 12345
test "$(_line2format__avangard "$(head -n 1 test-data/avangard.csv)")" = "5d23fa9895e0ff5af1557d49d5cab1ca;1645896000;14500;5912"
test "$(_line2format__tinkoff "$(head -n 2 test-data/tinkoff.csv | tail -n 1)" | md5sum | awk '{print $1}')" = "8c02c815b70f12a7403c26467a7340a6"

FREEKAZNA_DB_DIR="$TMP/db"
mkdir -p "$FREEKAZNA_DB_DIR"
FREEKAZNA_DB_TRANSACTIONS="$FREEKAZNA_DB_DIR/transactions.csv"
touch "$FREEKAZNA_DB_TRANSACTIONS"
_file2db__avangard test-data/avangard.csv
_file2db__raiffeisenrus test-data/raiffeisen-russia.csv
_file2db__tinkoff test-data/tinkoff.csv
cat  "$FREEKAZNA_DB_TRANSACTIONS"
test "$(cat "$FREEKAZNA_DB_TRANSACTIONS" | _select_by_mcc 5814 | md5sum | awk '{print $1}')" = "c8423b4a6d2b1302734e9cc07a43af68"
test "$(cat "$FREEKAZNA_DB_TRANSACTIONS" | _select_by_date 1653685200 1653771600 | md5sum | awk '{print $1}')" = "00f96575017d6e07a1b51fb481392968"
