#!/bin/bash
#
# Generate a makeself self-extracting archive from an AppImage matching
# the application name and the version.
#
set -eo pipefail
set -x

check_arguments() {
	local APP_NAME="$1"
	local RESULT_DIR="$2"
	local USAGE="Usage: $0 <app-name> <result-directory>"

	if [ -z ${RESULT_DIR} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
	if [ -z ${APP_NAME} ]; then
		printf "\n${USAGE}\n\n"
		exit 1
	fi
}

find_and_extract_appimage() {
	local RESULT_DIR="$1"
	local APP_NAME="$2"
	local VERSION="$3"
	local EXTRACT_DIR=""
	EXTRACT_DIR="$(set -e;pwd)/$4"
	local APPIMAGE_PATTERN="${APP_NAME}-${VERSION}-x86_64.AppImage"

	local TEMPFILE
	TEMPFILE="$(set -e;mktemp)"
	trap "{ rm -f ${TEMPFILE}; }" EXIT

	mkdir -p ${EXTRACT_DIR}
	pushd ${EXTRACT_DIR}

	find ${RESULT_DIR} -name "${APPIMAGE_PATTERN}" -print > "${TEMPFILE}"
	local COUNT=0
	COUNT="$(set -e; cat "${TEMPFILE}" | wc -l)"
	if [ ${COUNT} != 1 ]; then
		echo "None or more than one appimage '${APPIMAGE_PATTERN}' in '${RESULT_DIR}' found!"
		exit 1
	fi
	local FILENAME
	while read FILENAME; do
		chmod +x ${FILENAME}
		${FILENAME} --appimage-extract
	done < ${TEMPFILE}
	popd
}

create_setup_script() {
	local PACKAGE="$1"
	local APP_ID="$2"
	local PRODUCT_NAME="$3"
	local APP_NAME="$4"
	local DEST_DIR="$5"
	local TOOLS_DIR="$6"
	local REMOVE_DESKTOP_FILE_SCRIPT="$7"
	local FILENAME="$8"
	local DESKTOP_FILE="${APP_ID}.desktop"

	cat << EOFF > "${FILENAME}"
#!/bin/sh
set -eo pipefail

check_command() {
	local TOOL="\$1"

	if ! command -v \${TOOL} 2>&1 > /dev/null; then
		echo "Fatal: Command '\${TOOL}' could not be found, please install it and start \$0 again."
		exit 1
	fi
}

create_remove_desktop_file_script() {
	local XDG_DESKTOP_FILE_PATH="\$1"
	local FILENAME="\$2"

	cat << EOF > "\${FILENAME}"
#!/bin/sh
set -eo pipefail

main() {
	if [ -f "\${XDG_DESKTOP_FILE_PATH}" ]; then
		echo "Removing '\${XDG_DESKTOP_FILE_PATH}'"
		rm -f \${XDG_DESKTOP_FILE_PATH}
	else
		echo "File '\${XDG_DESKTOP_FILE_PATH}' was already removed"
	fi
}

main \\\$@
EOF
	chmod +x "\${FILENAME}"
}

modify_desktop_file() {
	local BINARY="\$1"
	local ICON="\$2"
	local FILENAME="\$3"

	sed -i -re "s|Exec=${PACKAGE}|Exec=\${BINARY}|" "\${FILENAME}"
	sed -i -re "s|TryExec=${PACKAGE}|TryExec=\${BINARY}|" "\${FILENAME}"
	sed -i -re "s|Icon=.*|Icon=\${ICON}|" "\${FILENAME}"
}

main() {
	check_command 'dirname'
	check_command 'realpath'
	check_command 'id'
	check_command 'rm'
	check_command 'cp'
	check_command 'sed'

	local SCRIPT_PATH
	local APP_DIR
	SCRIPT_PATH=\$(set -e;realpath "\$0")
	BIN_DIR=\$(set -e;dirname "\${SCRIPT_PATH}")
	APP_DIR=\$(set -e;dirname "\${BIN_DIR}")

	local XDG_PATHS="/usr/local/share /usr/share"
	local XDG_DESKTOP_FILE_PATH
	local DESKTOP_FILE="${DESKTOP_FILE}"
	local DESKTOP_FILE_PATH="\${APP_DIR}/share/applications/\${DESKTOP_FILE}"
	local REMOVE_DESKTOP_FILE_SCRIPT="\${BIN_DIR}/${REMOVE_DESKTOP_FILE_SCRIPT}"

	if [ \$(id -u) -eq 0 ]; then
		if [ -f "\${REMOVE_DESKTOP_FILE_SCRIPT}" ]; then
			"\${REMOVE_DESKTOP_FILE_SCRIPT}" 2>&1 > /dev/null
			rm -f "\${REMOVE_DESKTOP_FILE_SCRIPT}"
		fi
		if [ -f "\${DESKTOP_FILE_PATH}" ]; then
			for XDG_PATH in \${XDG_PATHS} ; do
				if [ -d \${XDG_PATH}/applications ]; then
					XDG_DESKTOP_FILE_PATH=\${XDG_PATH}/applications
					break
				fi
			done

			modify_desktop_file "\${BIN_DIR}/${PACKAGE}" "\${APP_DIR}/share/icons/hicolor/scalable/apps/${APP_ID}.svg" "\${DESKTOP_FILE_PATH}"
			if [ ! -z \${XDG_DESKTOP_FILE_PATH} ] && [ -d \${XDG_DESKTOP_FILE_PATH} ]; then
				cp "\${DESKTOP_FILE_PATH}" "\${XDG_DESKTOP_FILE_PATH}"
				create_remove_desktop_file_script "\${XDG_DESKTOP_FILE_PATH}/\${DESKTOP_FILE}" "\${REMOVE_DESKTOP_FILE_SCRIPT}"
			fi
		fi
	else
		echo "Warning: Setup is not executed with administrative privileges, skipping desktop integration."
	fi

	echo "${PRODUCT_NAME} was successfully set up in '\${APP_DIR}'."
}

main \$@
EOFF
	chmod +x "${FILENAME}"
}

create_uninstall_script() {
	local PRODUCT_NAME="$1"
	local DEST_DIR="$2"
	local REMOVE_DESKTOP_FILE_SCRIPT="$3"
	local FILENAME="$4"

	cat << EOFF > "${FILENAME}"
#!/bin/sh
set -eo pipefail

check_command() {
	local TOOL="\$1"

	if ! command -v \${TOOL} 2>&1 > /dev/null; then
		echo "Fatal: Command '\${TOOL}' could not be found"
		exit 1
	fi
}

remove_file() {
	FILE="\$1"
	echo "Removing file '\${FILE}'"
	rm "\${FILE}" || true
}

remove_dir() {
	DIR="\$1"
	echo "Removing directory '\${DIR}'"
	rmdir "\${DIR}" || true
}

main() {
	check_command 'dirname'
	check_command 'realpath'
	check_command 'id'
	check_command 'rm'
	check_command 'rmdir'

	local SCRIPT_PATH
	local APP_DIR
	SCRIPT_PATH=\$(set -e;realpath "\$0")
	BIN_DIR=\$(set -e;dirname "\${SCRIPT_PATH}")
	APP_DIR=\$(set -e;dirname "\${BIN_DIR}")
	local INSTALL_FILE_LIST="$(set -e;find . -mindepth 1 -type f | tac | sed 's#\./##g')
"
	local INSTALL_DIR_LIST="$(set -e;find . -mindepth 1 -type d | tac | sed 's#\./##g')
"

	if [ \$(id -u) -ne 0 ]; then
		echo "Fatal: Administrative privileges required for execution (use su or sudo)"
		exit 1
	fi

	if [ -f "\${BIN_DIR}/${REMOVE_DESKTOP_FILE_SCRIPT}" ]; then
		"\${BIN_DIR}/${REMOVE_DESKTOP_FILE_SCRIPT}"
		rm "\${BIN_DIR}/${REMOVE_DESKTOP_FILE_SCRIPT}"
	fi
	cd "\${APP_DIR}"
	for FILE in \${INSTALL_FILE_LIST}; do
		remove_file "\${APP_DIR}/\${FILE}"
	done
	remove_file "\${SCRIPT_PATH}"
	for DIR in \${INSTALL_DIR_LIST}; do
		remove_dir "\${APP_DIR}/\${DIR}"
	done
	remove_dir "\${APP_DIR}"
	echo "${PRODUCT_NAME} was successfully uninstalled."
}

main \$@
EOFF
	chmod +x "${FILENAME}"
}

create_wrapper_script() {
	local BINARY="$1"
	local FILENAME="$2"

	cat << EOFF > "${FILENAME}"
#! /usr/bin/env bash
set -eo pipefail

bin_dir="\$(readlink -f "\$(dirname "\$0")")"
root_dir="\$(dirname "\$bin_dir")"

APPDIR=\$root_dir
source "\$root_dir"/hooks/"linuxdeploy-plugin-gstreamer.sh"
source "\$root_dir"/hooks/"linuxdeploy-plugin-gtk.sh"

exec "\$bin_dir/${BINARY}" "\$@"

EOFF
	chmod +x "${FILENAME}"
}

main() {
	local PACKAGE="$1"
	local RESULT_DIR=""
	RESULT_DIR="$(set -e;pwd)/$2"

	check_arguments "${PACKAGE}" "${RESULT_DIR}"

	local BUILD_DIR="build/makeself"
	local SRC_DIR=""
	SRC_DIR="$(set -e;pwd)"
	local SCRIPT_DIR=""
	SCRIPT_DIR="$(set -e;dirname $0)"
	SCRIPT_DIR="$(set -e;realpath ${SCRIPT_DIR})"
	local ARCH=""
	ARCH="$(set -e;arch)"
	local SYSTEM=""
	SYSTEM="$(set -e;uname)"

	. ${SRC_DIR}/.build-env

	${SCRIPT_DIR}/check-build-env.sh

    local VERSION=""
	VERSION="$(set -e;cargo version-util get-version)"

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
	find_and_extract_appimage "${RESULT_DIR}" "${APP_NAME}" "${VERSION}" "tmp"

	rm -rf "${DEST_DIR}"
	mv tmp/squashfs-root "${DEST_DIR}"

	pushd "${DEST_DIR}"

	rm -f "usr/share/applications/${APP_ID}.desktop"
	# Remove AppImage added key:
	grep -v "X-AppImage-Version" "${APP_ID}.desktop" > "usr/share/applications/${APP_ID}.desktop"
	rm "${APP_ID}.desktop"

	rm -rf AppRun* .DirIcon *.svg
	mv usr/* .
	rmdir usr
	mv apprun-hooks hooks

	for HOOK in $(ls hooks/*); do
		sed -i 's#$APPDIR/usr#${APPDIR}#g' ${HOOK}
		sed -i 's#$APPDIR//usr#${APPDIR}#g' ${HOOK}
		sed -i 's#${APPDIR}/usr#${APPDIR}#g' ${HOOK}
		sed -i 's#pkgconfig/..##g' ${HOOK}
	done

	pushd bin
	for BINARY in $(ls); do
		mv ${BINARY} _${BINARY}
		create_wrapper_script "_${BINARY}" "${BINARY}"
	done
	popd

	create_setup_script "${PACKAGE}" "${APP_ID}" "${PRODUCT_PRETTY_NAME}" "${APP_NAME}" "${DEST_DIR}" "${TOOLS_DIR}" "${REMOVE_DESKTOP_FILE_SCRIPT}" "${STARTUP_SCRIPT}"
	create_uninstall_script "${PRODUCT_PRETTY_NAME}" "${DEST_DIR}" "${REMOVE_DESKTOP_FILE_SCRIPT}" "bin/uninstall.sh"
	popd

	mkdir -p "${RESULT_DIR}"
	/opt/makeself/makeself.sh --threads 0 --notemp --nooverwrite --keep-umask "${DEST_DIR}" "${RESULT_DIR}/${APP_NAME}-${VERSION}-${SYSTEM}-${ARCH}.run" "${APP_NAME}" "./${STARTUP_SCRIPT}"

	popd
}

main $@
