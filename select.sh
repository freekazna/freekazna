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
	
