#!/usr/bin/env bash
#
# This script fixes an issue with glib schemas provided by vcpkg.
# The schemas are not installed correctly by vcpkg, which leads to the following error message:
#
# Settings schema 'org.gtk.gtk4.Settings.FileChooser' is not installed
#
# set -x
set -eo pipefail


main() {
    local MXL_ENV_SCRIPT="./scripts/mxl-env.py"

    test -x ${MXL_ENV_SCRIPT}
    eval "$(set -e;${MXL_ENV_SCRIPT} --print-env)"

    local GLIB_COMPILE_SCHEMAS="./vcpkg_installed/${MXL_VCPKG_TRIPLET}/tools/glib/glib-compile-schemas"

    if [ -x ${GLIB_COMPILE_SCHEMAS} ]; then
        local SCHEMAS_DIR="./vcpkg_installed/${MXL_VCPKG_TRIPLET}/share/glib-2.0/schemas"

        # Set LD_LIBRARY_PATH to find all dependencies:
        LD_LIBRARY_PATH="${VCPKG_INSTALL_LIB_PATH}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" ${GLIB_COMPILE_SCHEMAS} ${SCHEMAS_DIR}
    fi
}

main "$@"
