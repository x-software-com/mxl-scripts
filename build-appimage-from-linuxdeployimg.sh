#!/bin/bash
#
# Generate an AppImage from a linuxdeployimg
#
set -e
set -x

check_arguments() {
	local APP_NAME="$1"
	local BUILD_TYPE="$2"
	local RESULT_DIR="$3"
	local USAGE="Usage: $0 <app-name> <build-type> <result-directory>"

	if [ -z ${RESULT_DIR} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
	if [ -z ${BUILD_TYPE} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
	if [ -z ${APP_NAME} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
}

find_and_extract_linuxdeployimg() {
	local RESULT_DIR="$1"
	local APP_NAME="$2"
	local VERSION="$3"
	local EXTRACT_DIR=""
	EXTRACT_DIR="$(set -e;pwd)/$4"
	local LINUXDEPLOYIMG_PATTERN="${APP_NAME}-${VERSION}-$(set -e;uname)-$(set -e;arch).tar.xz"

	local TEMPFILE
	TEMPFILE="$(set -e;mktemp)"
	trap "{ rm -f ${TEMPFILE}; }" EXIT

	mkdir -p ${EXTRACT_DIR}
	pushd ${EXTRACT_DIR}

	find ${RESULT_DIR} -name "${LINUXDEPLOYIMG_PATTERN}" -print > "${TEMPFILE}"
	local COUNT=0
	COUNT="$(set -e; cat "${TEMPFILE}" | wc -l)"
	if [ ${COUNT} != 1 ]; then
		echo "None or more than one linuxdeployimg '${LINUXDEPLOYIMG_PATTERN}' in '${RESULT_DIR}' found!"
		exit 1
	fi
	local FILENAME
	while read FILENAME; do
		tar -xvf ${FILENAME}
	done < ${TEMPFILE}
	popd
}

main() {
	local PACKAGE="$1"
	local BUILD_TYPE="$2"
	local RESULT_DIR=""
	RESULT_DIR="$(set -e;pwd)/$3"
	local SCRIPT_DIR=""
	SCRIPT_DIR="$(set -e;dirname $0)"
	SCRIPT_DIR="$(set -e;realpath ${SCRIPT_DIR})"

	check_arguments "${PACKAGE}" "${BUILD_TYPE}" "${RESULT_DIR}"

	local BUILD_DIR="build/appimage"
	local SRC_DIR=""
	SRC_DIR="$(set -e;pwd)"
    local VERSION=""
	VERSION="$(set -e;cargo version-util get-version)"

	local PACKAGE_VERSION="${VERSION}"
	if [ "${BUILD_TYPE}" != "release" ]; then
		PACKAGE_VERSION="debug-${VERSION}"
	fi

	. ${SRC_DIR}/.build-env

	${SCRIPT_DIR}/check-build-env.sh

	mkdir -p "${BUILD_DIR}"
	pushd "${BUILD_DIR}"

	rm -rf build
	mkdir build
	pushd build


	local MAJOR_VERSION=""
	MAJOR_VERSION="$(set -e;echo ${VERSION} | cut -d '.' -f 1)"
	local DEST_DIR="${PACKAGE}-${MAJOR_VERSION}"
	local STARTUP_SCRIPT="bin/setup.sh"
	local REMOVE_DESKTOP_FILE_SCRIPT="remove_desktop_file.sh"
	local TOOLS_DIR="libexec"

	rm -rf tmp
	find_and_extract_linuxdeployimg "${RESULT_DIR}" "${PACKAGE}" "${PACKAGE_VERSION}" "tmp"

	rm -rf "${DEST_DIR}"
	mv tmp "${DEST_DIR}"

	mkdir -p "${RESULT_DIR}"

	export LINUXDEPLOY_OUTPUT_VERSION=${VERSION}
	linuxdeploy-plugin-appimage --appdir "${DEST_DIR}"
	mv *.AppImage "${RESULT_DIR}"

	popd
}

main $@
