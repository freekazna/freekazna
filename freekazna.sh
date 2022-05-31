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

# if running from directory with code
if [ -f freekazna.sh ]
then
	FREEKAZNA_BANKS_DIR="$PWD/banks"
else
	FREEKAZNA_BANKS_DIR="@DATADIR@/freekazna/banks"
fi

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

# Pull requests and patches with support of CSVs/JSONs/XMLs/XSLS(X)x/HTMLs/PDFs/etc from other banks are welcomed!
BANK="${BANK:-avangard}"
SUPPORTED_BANKS=(avangard raiffeisenrus)
for i in ${SUPPORTED_BANKS[@]}
do
	. "$FREEKAZNA_BANKS_DIR"/"$i".sh
done

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
	if [ -z "$1" ]; then
		_ee "Empty line for adding into DB, skipping"
		return 0
	fi
	local arr
	IFS=';' read -a arr <<< "$1"
	_add_transaction_to_db "${arr[0]}" "${arr[1]}" "${arr[2]}" "${arr[3]}"
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
	
