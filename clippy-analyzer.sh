#!/bin/bash
#
# Cleanup the verbose output of clippy and print the remaining output:
#
# set -x

main() {
	local LOG_FILE="$1"
	local CLEAN_LOG_FILE="$2"
	local USAGE="Usage: $0 <full-clippy-log> <clean-clippy-log>\n\ne.g. $0 raw_clippy.log clippy.log"

    if [ -z ${LOG_FILE} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
    if [ -z ${CLEAN_LOG_FILE} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi

	cat ${LOG_FILE} \
		| grep -v "^    Checking \|^   Compiling \|^  Downloaded \|^ Downloading \|^    Updating crates.io index\|^    Finished " \
		> ${CLEAN_LOG_FILE}

	if [ "$(set -e; cat ${CLEAN_LOG_FILE} | wc -l)" != "0" ]; then
		echo " +---------------------------------------------------+ "
		echo " |----------- Detected some clippy issues -----------| "
		echo " +---------------------------------------------------+ "
		echo ""
		cat ${CLEAN_LOG_FILE}
		exit 1
	fi
}

main $@
