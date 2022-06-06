#!/usr/bin/env bash

# $1: date
# Example:
# 26.02.2022 20:20
# the same as Avangard
_date2unix__tinkoff(){
	_date2unix__avangard "$1"
}

# $1: sum in rub.kop
# Example:
# -560 (560 rub)
# results to 56000 kop.
# XXX Не знаю, как отображаются нецелые числа, поэтому на всякий случай заменим запятую на точку
_sum2integer__tinkoff(){
	local arr
	IFS='.' read -a arr <<< "$(echo "$1 * 100" | sed -e 's,^-,,' -e 's/,/./g' | bc)"
	echo "${arr[0]}"
}

# Example CSV from Tinkoff is in test-data/tinkoff.csv
# $1: line
_line2format__tinkoff(){
	if [ -z "$1" ]; then
		_ee "Skipping empty line..."
		return 0
	fi
	local arr
	# XXX For now iconv is actually not needed because we do not use that field
	IFS=';' read -a arr <<< "$(echo "$1" | iconv -f cp1251)"
	# Траты денег (7-ая колонка) начинаются с минуса
	# Колонка с MCC (11-ая) пустая для платежей типа переводов между счетами
	if [ "${arr[6]:0:1}" != '-' ] || [ -z "${arr[10]}" ]; then
		_ee "Skipping line not about spending money..."
		return 0
	fi
	local md5
	local time
	local sum
	local mcc
	md5="$(_string2md5 "$1")"
	time="$(_date2unix__tinkoff "${arr[0]}")"
	sum="$(_sum2integer__tinkoff "${arr[6]}")"
	mcc="${arr[10]}"
	echo "${md5};${time};${sum};${mcc}"
}

# $1: path to csv file
_file2db__tinkoff(){
	while read -r line
	do
		_add_formatted_line_to_db "$(_line2format__tinkoff "$line")"
	done < <(cat "$1")
}
