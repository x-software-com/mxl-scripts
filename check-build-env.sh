#!/bin/bash
#
# Check if the required environment variables are set
#
set -e
set -x

check_env_value() {
    local VARIABLE="$1"

    if [ "${!VARIABLE}" = "" ]; then
        printf "\nVariable ${VARIABLE} not set in build-env\n\n"
        exit 1
    fi
}

main() {
    check_env_value LICENSES_DIR
    check_env_value APP_ID_BASE
    check_env_value PACKAGE
    check_env_value APP_NAME
    check_env_value PRODUCT_PRETTY_NAME
    check_env_value APP_ID
}

main $@
