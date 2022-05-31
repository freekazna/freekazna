#!/usr/bin/env bash

#set -x
set -e
set -f
set -u
set -o pipefail

# echo error
_ee(){
	echo "$@" 1>&2
}

# https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
FREEKAZNA_DB_DIR="${FREEKAZNA_DB_DIR:-$XDG_DATA_HOME/freekazna}"
mkdir -p "$FREEKAZNA_DB_DIR"
FREEKAZNA_DB_TRANSACTIONS="${FREEKAZNA_DB_TRANSACTIONS:-$FREEKAZNA_DB_DIR/transactions.csv}"

# https://github.com/greggles/mcc-codes
FREEKAZNA_MCC_DB="${FREEKAZNA_MCC_DB:-}"
if [ -z "$FREEKAZNA_MCC_DB" ]; then
	if [ -f mcc_codes.csv ]; then
		FREEKAZNA_MCC_DB="mcc_codes.csv"
	elif [ -f "@DATADIR@/freekazna/mcc_codes.csv" ]; then
		FREEKAZNA_MCC_DB="@DATADIR@/freekazna/mcc_codes.csv"
	else
		_ee "Database with MCC codes not found!"
		exit 1
	fi
fi

# Currently only avangard.ru is supported
# Pull requests and patches with support of CSVs from other banks are welcomed!
BANK="${BANK:-avangard}"
SUPPORTED_BANKS=(avangard)

CURRENCY_SIGN="${CURRENCY_SIGN:-₽}"
		
# $1: commit message
_git(){
	[ -n "${1:-}" ]
	pushd "$FREEKAZNA_DB_DIR" >/dev/null
	if ! test -d ".git"; then
		git init
		git config user.name FreeKazna
		git config user.email freekazna@localhost.tld
	fi
	git add .
	git commit -m "$1"
	if [ "$(git remote -v | grep -c .)" -gt 0 ]; then
		git push
	fi
	popd
}

# $1: bank
_check_bank_is_supported(){
	local ok
	ok=0
	for (( a = 0; a < ${#SUPPORTED_BANKS[@]}; a++ ))
	do
		if [ "$1" = "${SUPPORTED_BANKS[$a]}" ]; then
			ok=1
			break
		fi
	done
	test "$ok" = 1
}

# $1: MCC code
_mcc2description(){
	local o
	IFS=',' read -a o <<< "$(set -e && set -o pipefail && grep "^$1," "$FREEKAZNA_MCC_DB" | head -n1)"
	[ -n "${o[1]}" ] || return 1
	# second column from csv
	echo "${o[1]}"
}

# $1: string
_string2md5(){
	# XXX Why is "|| return 1" needed despite set -e?
	[ -n "$*" ] || return 1
	local o
	read -a o <<< "$(echo "$@" | md5sum)"
	[ -n "${o[0]}" ]
	echo "${o[0]}"
}

# $1: MD5 of the transaction string
_is_transaction_in_db(){
	grep -q "^${1};" "$FREEKAZNA_DB_TRANSACTIONS"
}

# $1: MD5 of the string from the original imported data
# $2: time of transaction (UNIX timestamp)
# $3: sum spent (how much money was spent in your currency)
# $4: MCC code of the transaction (use "0" if no code)
_add_transaction_to_db(){
	for i in "$1" "$2" "$3" "$4"
	do
		if [[ "$i" =~ .*';'.* ]]; then
			_ee "Error adding transaction into db: symbol ; is used as a delimeter"
			return 1
		fi
	done
	if grep -q "^$1;" "$FREEKAZNA_DB_TRANSACTIONS"; then
		_ee "Line with MD5 $1 already exists in the DB, skipping it"
		return 0
	fi
	echo "${1};${2};${3};${4}" >> "$FREEKAZNA_DB_TRANSACTIONS"
}

# $1: "${md5};${time};${sum};${mcc}"
_add_formatted_line_to_db(){
	IFS=';' read -a arr <<< "$1"
	_add_transaction_to_db "${arr[0]}" "${arr[1]}" "${arr[2]}" "${arr[3]}"
}

# $1: date
# Example:
# 26.02.2022 20:20
_date2unix__avangard(){
	local arr1
	IFS=' ' read -a arr1 <<< "$(echo "$1")"
	local d
	IFS='.' read -a d <<< "$(echo "${arr1[0]}")"
	local day
	day="${d[0]}"
	local month
	month="${d[1]}"
	local year
	year="${d[2]}"
	local t
	IFS=':' read -a t <<< "$(echo "${arr1[1]}")"
	local hour
	hour="${t[0]}"
	local minute="${t[1]}"
	local second
	second=00
	# XXX В выгрузке из Авангарда в городах с немосковским временем время московское или местное?
	# Предположим, что московское.
	date +%s --date="TZ=\"Europe/Moscow\" ${year}-${month}-${day} ${hour}:${minute}:${second}"
}

# $1: sum in rub.kop
# Example:
# 560.50 (560 rub 50 kop)
# results to 56050 kop.
_sum2integer__avangard(){
	local arr
	IFS='.' read -a arr <<< "$(echo "$1 * 100" | bc)"
	echo "${arr[0]}"
}

# Example CSV from Avangard is in test-data/avangard.csv
# $1: line
_line2format__avangard(){
	local arr
	# XXX For now iconv is actually not needed because we do not use that field
	IFS=';' read -a arr <<< "$(echo "$1" | iconv -f cp1251 | sed -e 's,",,g')"
	local md5
	local time
	local sum
	local mcc
	md5="$(_string2md5 "$1")"
	time="$(_date2unix__avangard "${arr[4]}")"
	sum="$(_sum2integer__avangard "${arr[2]}")"
	mcc="${arr[8]}"
	echo "${md5};${time};${sum};${mcc}"
}

# $1: path to csv file
_file2db__avangard(){
	while read -r line
	do
		_add_formatted_line_to_db "$(_line2format__avangard "$line")"
	done < <(cat "$1")
}

_main(){
	if ! _check_bank_is_supported "$BANK" ; then
		_ee "Bank $BANK is not supported"
		return 1
	fi
}

if [ "${SOURCING:-0}" = 0 ]; then
	_main "$@"
fi
	
