#!/usr/bin/env python3
"""Setup VCPKG to build and develop a MXL project"""

import os
import subprocess
import pathlib
from sys import platform as sys_platform
import platform

from .triplet import triplet

SCRIPTDIR = pathlib.Path(os.path.abspath(os.path.dirname(__file__))).parent


def bootstrap(release):
    """Bootstrap VCPKG: 1. Download or update existing vckpg, 2. call bootstrap-vcpkg script"""
    if os.path.isdir('vcpkg'):
        os.system('cd vcpkg && git fetch && cd ..')
    else:
        subprocess.run(['git', 'clone', 'https://github.com/Microsoft/vcpkg.git'], check = True)

    os.system(f'cd vcpkg && git checkout {release} && cd ..')

    if sys_platform.startswith('darwin'):
        subprocess.run(['./vcpkg/bootstrap-vcpkg.sh', '-disableMetrics', '-allowAppleClang'], check = True)
    elif sys_platform.startswith('darwin'):
        subprocess.run(['./vcpkg/bootstrap-vcpkg.bat', '-disableMetrics'], check = True)
    else:
        subprocess.run(['./vcpkg/bootstrap-vcpkg.sh', '-disableMetrics'], check = True)


def setup_vcpkg(package, release):
    """Setup VCPKG according to the vcpkg-configuration.json for MXL"""

    # Enable VCPKG_FORCE_SYSTEM_BINARIES for Linux AArch64 builds
    if sys_platform.startswith('linux') and platform.machine().startswith('aarch64'):
        os.environ["VCPKG_FORCE_SYSTEM_BINARIES"] = "true"

    bootstrap(release)

    # Workaround for vcpkg release 2023.07.21, a package that is built as the first one
    # tries to access tools by using './vcpkg_installed/<triplet>/../x64-linux/<tool-path>'.
    # But the latest release does not crate the triplet directory before this call, so the
    # build fails with: No such file or directory
    pathlib.Path(f'./vcpkg_installed/{triplet()}').mkdir(parents=True, exist_ok=True)

    vcpkg_cache_path = pathlib.Path().home().absolute().joinpath(f'.cache/vcpkg/{package}-archive')
    vcpkg_cache_path.mkdir(parents=True, exist_ok=True)

    vcpkg_args = ['./vcpkg/vcpkg', 'install', f'--triplet={triplet()}', f'--binarysource=clear;files,{vcpkg_cache_path.absolute()},readwrite' , '--recurse']

    res = subprocess.run(vcpkg_args, check = True)
    if res.returncode != 0:
        if sys_platform.startswith('darwin'):
            print("Execute 'brew install nasm bison autoconf automake yasm pkg-config meson cmake' as ci-user")
        raise res.stderr
    subprocess.run([f'{SCRIPTDIR}/setup-gdkpixbuf.sh'], check = True)
    subprocess.run([f'{SCRIPTDIR}/setup-glib-schemas.sh'], check = True)
