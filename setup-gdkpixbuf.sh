#!/bin/bash
# set -x
set -e

# To enable SVG images in GTK, GDK-Pixbuf has to find the correct gdkpixbuf-loader for SVG provided by librsvg.
# GDK-Pixbuf in the relocatable mode reads the link provided by '/proc/self/exe' (which resolves to '$MXL_GIT_DIR/target/$BUILD_MODE/$BINARY').
# Then it goes to the parent directory and searches for 'lib/gdk-pixbuf-2.0/2.10.0/loaders.cache', which should contain all found loaders.
#
# The libpixbufloader-svg.so file is installed into the wrong directory. So we copy it into the loaders directory, update the cache and link the
# lib directory to the target directory.

fix_gdk_pixbuf() {
    local SRC_DIR="$1"
    local TYPE="$2"

    case "${TYPE}" in
    debug)
        LIB_PATH="debug/lib"
        eval "$(./mxl-env.py --print-env --vcpkg-debug)"
        ;;
    release)
        LIB_PATH="lib"
        eval "$(./mxl-env.py --print-env)"
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
        ./vcpkg_installed/${MXL_VCPKG_TRIPLET}/tools/gdk-pixbuf/gdk-pixbuf-query-loaders --update-cache
    fi
}

main() {
    local SRC_DIR=""
    SRC_DIR="$(set -e;pwd)"

    # Use subshells to prevent environment poisoning:
    (fix_gdk_pixbuf "${SRC_DIR}" "release")
    (fix_gdk_pixbuf "${SRC_DIR}" "debug")
}

main $@
