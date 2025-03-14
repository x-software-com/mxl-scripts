#!/bin/bash
# set -x
set -eo pipefail

# To enable SVG images in GTK, GDK-Pixbuf has to find the correct gdkpixbuf-loader for SVG provided by librsvg.
# GDK-Pixbuf in the relocatable mode reads the link provided by '/proc/self/exe' (which resolves to '$MXL_GIT_DIR/target/$BUILD_MODE/$BINARY').
# Then it goes to the parent directory and searches for 'lib/gdk-pixbuf-2.0/2.10.0/loaders.cache', which should contain all found loaders.
#
# The libpixbufloader-svg.so file is installed into the wrong directory. So we copy it into the loaders directory, update the cache and link the
# lib directory to the target directory.

fix_gdk_pixbuf() {
    local SRC_DIR="$1"
    local TYPE="$2"
    local MXL_ENV_SCRIPT="./scripts/mxl-env.py"

    test -x ${MXL_ENV_SCRIPT}
    case "${TYPE}" in
    debug)
        LIB_PATH="debug/lib"
        eval "$(set -e;${MXL_ENV_SCRIPT} --print-env --vcpkg-debug)"
        ;;
    release)
        LIB_PATH="lib"
        eval "$(set -e;${MXL_ENV_SCRIPT} --print-env)"
        ;;
    *)
        echo ""
        echo "Unknown type '${TYPE}'. Exiting..."
        echo ""
        exit 1
        ;;
    esac

    local GDK_PIXBUF_QUERY_LOADERS="./vcpkg_installed/${MXL_VCPKG_TRIPLET}/tools/gdk-pixbuf/gdk-pixbuf-query-loaders"

    if [ -x ${GDK_PIXBUF_QUERY_LOADERS} ]; then
        local GDK_PIXBUF_BINARY_VERSION=""
        GDK_PIXBUF_BINARY_VERSION="$(set -e;pkg-config gdk-pixbuf-2.0 --variable=gdk_pixbuf_binary_version)"
        local GDK_PIXBUF_LOADER_DIR="${SRC_DIR}/vcpkg_installed/${MXL_VCPKG_TRIPLET}/${LIB_PATH}/gdk-pixbuf-2.0/${GDK_PIXBUF_BINARY_VERSION}"

        export GDK_PIXBUF_MODULEDIR="${GDK_PIXBUF_LOADER_DIR}/loaders"
        export GDK_PIXBUF_MODULE_FILE="${GDK_PIXBUF_LOADER_DIR}/loaders.cache"
        # Set LD_LIBRARY_PATH to find all dependencies of the GdkPixbuf plugins:
        LD_LIBRARY_PATH="${VCPKG_INSTALL_LIB_PATH}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" ./vcpkg_installed/${MXL_VCPKG_TRIPLET}/tools/gdk-pixbuf/gdk-pixbuf-query-loaders --update-cache
    fi
}

main() {
    local SRC_DIR=""
    SRC_DIR="$(set -e;pwd)"

    # Use subshells to prevent environment poisoning:
    (set -e;fix_gdk_pixbuf "${SRC_DIR}" "release")
    (set -e;fix_gdk_pixbuf "${SRC_DIR}" "debug")
}

main $@
