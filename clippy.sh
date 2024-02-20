#!/bin/bash
#
# Execute cargo clippy and print a cleaned up version of the output:
#
# set -x
set -e


main() {
    local CLEAN_LOG_FILE="clippy.log"
    local FULL_LOG_FILE="clippy-full.log"
    local SCRIPT_DIR=""
    SCRIPT_DIR="$(set -e;dirname $0)"
    SCRIPT_DIR="$(set -e;realpath ${SCRIPT_DIR})"

    (
        # set -o pipefail exits the script if a command piped with tee exits with an error
        set -o pipefail
        cargo clippy --release --all-targets |& tee ${FULL_LOG_FILE}
    )
    ${SCRIPT_DIR}/clippy-analyzer.sh ${FULL_LOG_FILE} ${CLEAN_LOG_FILE}
}

main $@
