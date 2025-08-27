#!/usr/bin/env bash
#
# Create a AppImage for the given MXL product.
#
set -eo pipefail
set -x

check_arguments() {
	local PACKAGE="$1"
	local BUILD_TYPE="$2"
	local BINARY="$3"
	local BUILD_DIR="$4"
	local PKG_DIR="$5"
	local RESULT_DIR="$6"
	local USAGE="Usage: $0 <package> <build-type> <binary> <build-directory> <pkgdir> <result-directory>\n\ne.g. $0 mxl_player release|debug mxl_player builddir pkgdir result"

	if [ -z ${PACKAGE} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
	if [ -z ${BUILD_TYPE} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
	if [ -z ${BINARY} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
	if [ -z ${BUILD_DIR} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
	if [ -z ${PKG_DIR} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
	if [ -z ${RESULT_DIR} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
}

extract_debug_and_strip() {
	local FILENAME="$1"
	local DEBUG_FILENAME="$2"

	echo "stripping ${FILENAME}, putting debug info into ${DEBUG_FILENAME}"
	objcopy --only-keep-debug "${FILENAME}" "${DEBUG_FILENAME}"
	strip --strip-debug --strip-unneeded "${FILENAME}"
	objcopy --add-gnu-debuglink="${DEBUG_FILENAME}" "${FILENAME}"
	chmod -x "${DEBUG_FILENAME}"
}

main() {
	local PACKAGE="$1"
	local BUILD_TYPE="$2"
	local BINARY="$3"
	local BUILD_DIR="$4"
	local PKG_DIR="$5"
	local RESULT_DIR=""
	RESULT_DIR="$(set -e;pwd)/$6"
	local LICENSES_DIR="${PKG_DIR}/usr/share/licenses"
	local SRC_DIR=""
	SRC_DIR="$(set -e;pwd)"
	local SCRIPT_DIR=""
	SCRIPT_DIR="$(set -e;dirname $0)"
	SCRIPT_DIR="$(set -e;realpath ${SCRIPT_DIR})"

	check_arguments "$1" "$2" "$3" "$4" "$5" "$6"

	. ${SRC_DIR}/.build-env

	${SCRIPT_DIR}/check-build-env.sh

	local VERSION_PREFIX=""
	if [ "${BUILD_TYPE}" != "release" ]; then
		VERSION_PREFIX="debug-"
		sed -i 's#Name=\(.*\)#Name=\1 debug#' ${BUILD_DIR}/${PKG_DIR}/usr/share/applications/${APP_ID}.desktop
	fi

	local VERSION=""
	VERSION="${VERSION_PREFIX}$(set -e;cargo version-util get-version)"

	local PACKAGE_NAME="${PACKAGE}-${VERSION}-$(set -e;uname)-$(set -e;arch)"

	cargo install --version 0.1.3 sancus

	local TRIPLET="$(set -e;${SCRIPT_DIR}/get-vcpkg-triplet.py)"

	pushd "${BUILD_DIR}"


	local CENTOS7_LIBS=""
	if [[ $(set -e;lsb_release -sir) == CentOS\ 7* ]]; then
		# These libraries must be deployed manually for centos7 because of too old system library versions
		CENTOS7_LIBS="--library ../vcpkg_installed/${TRIPLET}/lib/libfribidi.so.0 \
					  --library ../vcpkg_installed/${TRIPLET}/lib/libz.so.1 \
					  --library ../vcpkg_installed/${TRIPLET}/lib/libfontconfig.so.1 \
					  --library ../vcpkg_installed/${TRIPLET}/lib/libfreetype.so.6"
	fi

	local COSMIC_LIBS=""
	# cosmic has dependencies witch uses libxcb - libxcb is on the excludelist
	# Without this lib, Ubuntu 16.04.2 will fail with: failed to load symbol 'xcb_send_request_with_fds64'
	COSMIC_LIBS="--library /usr/lib64/libxcb.so.1"

	GSTREAMER_LIBS=""
	# gstreamer plugins has dependencies witch uses wayland - libwayland-client is on the excludelist
	# Without this lib, Ubuntu 16.04.2 will fail with: ../libwayland-cursor.so.0: undefined symbol: wl_proxy_marshal_flags
	GSTREAMER_LIBS="--library /usr/local/lib64/libwayland-client.so.0"
	

	LD_LIBRARY_PATH="${VCPKG_INSTALL_LIB_PATH}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" NO_STRIP=1 GSTREAMER_INCLUDE_BAD_PLUGINS="1" GSTREAMER_PLUGINS_DIR="${VCPKG_INSTALL_PLUGINS_PATH}/gstreamer" GSTREAMER_HELPERS_DIR="${VCPKG_INSTALL_PATH}/tools/gstreamer" DEBUG="1" linuxdeploy \
		--verbosity=0 --appdir ${PKG_DIR} --plugin gstreamer \
		--library ../vcpkg_installed/${TRIPLET}/lib/libharfbuzz.so.0 \
		${CENTOS7_LIBS} ${COSMIC_LIBS} ${GSTREAMER_LIBS} \
		${ADDITIONAL_LINUXDEPLOY_ARGS} \
		--executable ${PKG_DIR}/usr/bin/${BINARY} \
		--desktop-file ${PKG_DIR}/usr/share/applications/${APP_ID}.desktop

	# Remove some libraries/files manually...
	# The linuxdeploy --exclude-library argument does not work for plugins like linuxdeploy-plugin-gtk.

	# libGLESv2 is linked to libglapi.so which is already excluded by the official exclusion list.
	# https://github.com/AppImageCommunity/pkg2appimage/blob/master/excludelist
	echo "Remove libGLESv2 that should be provided by proprietary drivers"
	rm -f ${PKG_DIR}/usr/lib/libGLESv2.so.2

	# libva* libraries should be used from the system
	echo "Remove libva* libraries"
	rm -f ${PKG_DIR}/usr/lib/libva.so.2
	rm -f ${PKG_DIR}/usr/lib/libva-x11.so.2
	rm -f ${PKG_DIR}/usr/lib/libva-wayland.so.2
	rm -f ${PKG_DIR}/usr/lib/libva-drm.so.2

	pushd ${PKG_DIR}

	echo "Fix apprun-hooks"
	for HOOK in $(ls apprun-hooks/*); do
		sed -i 's#pkgconfig/..##g' ${HOOK}
		sed -i "s#${SRC_DIR}/vcpkg_installed/$(set -e;${SCRIPT_DIR}/get-vcpkg-triplet.py)/##g" ${HOOK}
	done

	# Add cosmic specific application hook
	cat > apprun-hooks/cosmic.sh<< EOF
#!/usr/bin/env bash

# Extend XDG_DATA_DIRS environment variable to include the AppImage's data directory - required to find the icons
export XDG_DATA_DIRS="\$XDG_DATA_DIRS:\$APPDIR/usr/share"

# If WGPU uses the Vulkan backend on older operating systems (like Ubuntu 16.04),
# the GUI will start with an empty window. This setting corrects that:
export WGPU_BACKEND=gl # possible values: vulkan, metal, dx11, dx12, gl, webgpu
EOF

	local SOURCES_FIX_DIR=""
	local SOURCES_FIX_DIR=".${SRC_DIR}/vcpkg_installed/$(set -e;${SCRIPT_DIR}/get-vcpkg-triplet.py)"
	if [ -d ${SOURCES_FIX_DIR} ]; then
		rsync -a ${SOURCES_FIX_DIR}/* usr
		local SOURCES_BASE_DIR=""
		SOURCES_BASE_DIR="$(set -e;echo ${SOURCES_FIX_DIR} | cut -d "/" -f2)"
		rm -rf ${SOURCES_BASE_DIR}
	fi

	# Run binary directly:
	sed -i "s#AppRun.wrapped#usr/bin/${BINARY}#g" AppRun
	rm AppRun.wrapped
	popd

	# Set APPDIR variable and cosmic for apprun-hooks:
	sed -i 's#source "$this_dir"/apprun-hooks/"linuxdeploy-plugin-gstreamer.sh"#APPDIR=$this_dir\nsource "$this_dir"/apprun-hooks/"cosmic.sh"\nsource "$this_dir"/apprun-hooks/"linuxdeploy-plugin-gstreamer.sh"#g' ${PKG_DIR}/AppRun

	mkdir -p "${RESULT_DIR}"

	# Extract debug information and stripping libraries and binary files:
	# Note: do not strip gstreamer binaries like gst-inspect - they will be corrupted and crash (mime-type: application/x-executable)
#	local BUILD_DIR_ABS=${PWD}
#	pushd ${PKG_DIR}
#	find . -type f -exec file --mime-type "{}" \; > "${BUILD_DIR_ABS}/pkg_file_list.txt"
#	local DEBUG_FILENAMES=""
#	for FILE_NAME in $(cat "${BUILD_DIR_ABS}/pkg_file_list.txt" | grep ": application/x-sharedlib" | awk -F': application/x-sharedlib' '{print $1}'); do
#		local DEBUG_FILENAME="${FILE_NAME}.debug"
#		extract_debug_and_strip "${FILE_NAME}" "${DEBUG_FILENAME}"
#		DEBUG_FILENAMES="${DEBUG_FILENAMES} ${DEBUG_FILENAME}"
#	done
#	tar -cJf "${RESULT_DIR}/${PACKAGE_NAME}.debuginfo.tar.xz" ${DEBUG_FILENAMES}
#	rm ${DEBUG_FILENAMES}
#	popd

#	sancus create --package-name ${PACKAGE} --project-path ${SRC_DIR} --package-path ${PKG_DIR} \
#		--result-path ${LICENSES_DIR} --additional-third-party-licenses ${LICENSES_DIR}/${BINARY}_third_party_licenses.json \
#		${ADDITIONAL_SANCUS_ARGS} 2>&1 | tee ${RESULT_DIR}/sancus.log

	pushd ${PKG_DIR}
	tar -cJf "${RESULT_DIR}/${PACKAGE_NAME}.tar.xz" *
	popd

	popd
}

main "$1" "$2" "$3" "$4" "$5" "$6"
