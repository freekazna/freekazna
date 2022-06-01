#!/usr/bin/env bash
# Functions for selecting data from database

# $1: MCC code
# input into stdin
_select_by_mcc(){
	while read -r line
	do
		local arr
		IFS=';' read -a arr <<< "$line"
		local mcc
		mcc="${arr[3]}"
		if [ -z "$mcc" ]; then
			return 1
		fi
		if [ "$mcc" = "$1" ]; then
			echo "$line"
		fi
	done
}

# $1: start date (UNIX timestamp)
# $2: end date (UNIX timestamp)
# input into stdin
_select_by_date(){
	while read -r line
	do
		local arr
		IFS=';' read -a arr <<< "$line"
		local date
		date="${arr[1]}"
		if [ -z "$date" ]; then
			return 1
		fi
		if (( "$date" >= "$1" )) && (( "$date" <= "$2" )); then
			echo "$line"
		fi
	done
}
