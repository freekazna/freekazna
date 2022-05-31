#!/usr/bin/env bash

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
	if [ -z "$1" ]; then
		_ee "Skipping empty line..."
		return 0
	fi
	local arr
	# XXX For now iconv is actually not needed because we do not use that field
	IFS=';' read -a arr <<< "$(echo "$1" | iconv -f cp1251 | sed -e 's,",,g')"
	# строка-пополнение счета
	if [ -n "${arr[1]}" ]; then
		_ee "Skipping line..."
		return 0
	fi
	# оплата по QR СБП, для которой не заполнены столбцы даты, MCC и пр.
	if [ -z "${arr[4]}" ]; then
		_ee "Skipping line..."
		return 0
	fi
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
