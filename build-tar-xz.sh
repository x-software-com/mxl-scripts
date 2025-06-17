#!/usr/bin/env bash
#
# Generate a .tar.xz file of the given package
#
set -eo pipefail
set -x

check_arguments() {
	local PACKAGE="$1"
	local BUILD_DIR="$2"
	local PKG_DIR="$3"
	local RESULT_DIR="$4"
	local USAGE="Usage: $0 <package> <build-directory> <pkgdir> <result-directory>\n\ne.g. $0 mxl_player builddir pkgdir result"

	if [ -z ${PACKAGE} ]; then
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

main() {
	local PACKAGE="$1"
	local BUILD_DIR="$2"
	local PKG_DIR="$3"
	local RESULT_DIR=""
	RESULT_DIR="$(set -e;pwd)/$4"
	local LICENSES_DIR="${PKG_DIR}/usr/share/licenses"
	local SRC_DIR=""
	SRC_DIR="$(set -e;pwd)"
	local SCRIPT_DIR=""
	SCRIPT_DIR="$(set -e;dirname $0)"
	SCRIPT_DIR="$(set -e;realpath ${SCRIPT_DIR})"

	check_arguments "$1" "$2" "$3" "$4"

	. ${SRC_DIR}/.build-env

	${SCRIPT_DIR}/check-build-env.sh

	cargo install --version 0.1.0 sancus

	local VERSION="$(set -e;cargo version-util get-version)"
	local TAR_PACKAGE_NAME="${PACKAGE}-${VERSION}-$(set -e;${SCRIPT_DIR}/get-vcpkg-triplet.py).tar.xz"

	pushd ${BUILD_DIR}

	sancus export ${LICENSES_DIR} ${LICENSES_DIR}/com.x-software.mxl.gstmxlcompositor_third_party_licenses.json

	pushd ${PKG_DIR}

	mkdir -p ${RESULT_DIR}
	tar -cJf ${RESULT_DIR}/${TAR_PACKAGE_NAME} *

	popd
}

main "$1" "$2" "$3" "$4"
