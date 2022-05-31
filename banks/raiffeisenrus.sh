#!/usr/bin/env bash

# $1: date
# Example:
# 26.02.2022 20:20
# the same as Avangard, HH:MM is always 00:00
_date2unix__raiffeisenrus(){
	_date2unix__avangard "$1"
}

# $1: sum in rub.kop
# Example:
# -560.50 (560 rub 50 kop)
# results to 56050 kop.
_sum2integer__raiffeisenrus(){
	local arr
	IFS='.' read -a arr <<< "$(echo "$1 * 100" | sed -e 's,^-,,' -e 's, ,,' | bc)"
	echo "${arr[0]}"
}

# Example CSV from Raiffeisen Russian is in test-data/raiffeisen-russia.csv
# $1: line
_line2format__raiffeisenrus(){
	if [ -z "$1" ]; then
		_ee "Skipping empty line..."
		return 0
	fi
	local arr
	# XXX For now iconv is actually not needed because we do not use that field
	IFS=';' read -a arr <<< "$(echo "$1" | iconv -f cp1251)"
	if [ -z "${arr[7]}" ] || [ "${arr[7]:0:1}" != '-' ]; then
		_ee "Skipping line not about spending money..."
		return 0
	fi
	local md5
	local time
	local sum
	local mcc
	md5="$(_string2md5 "$1")"
	# в выгрузках Райффайзена есть дата, а время всегда 00:00
	time="$(_date2unix__raiffeisenrus "${arr[0]}")"
	sum="$(_sum2integer__raiffeisenrus "${arr[7]}")"
	# MCC нет в выгрузке Райффайзена
	mcc=0
	echo "${md5};${time};${sum};${mcc}"
}

# $1: path to csv file
_file2db__raiffeisenrus(){
	while read -r line
	do
		_add_formatted_line_to_db "$(_line2format__raiffeisenrus "$line")"
	done < <(cat "$1")
}
