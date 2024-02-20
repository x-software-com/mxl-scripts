"""Helper to get the VCPGK triplet for the current platform"""

from sys import platform as sys_platform
import platform

def triplet():
    """"Get triplet for dynamic libraries and applications built with VCPKG"""
    if sys_platform.startswith('darwin'):
        if platform.machine().startswith('arm64'):
            return 'arm64-osx-dynamic'
        else:
            return 'x64-osx-dynamic'
    # elif sys_platform.startswith('win32'):
    #     return '...-dynamic'
    else:
        return 'x64-linux-dynamic'

def triplet_static():
    """"Get triplet for static VCPKG artifacts"""
    if sys_platform.startswith('darwin'):
        if platform.machine().startswith('arm64'):
            return 'arm64-osx'
        else:
            return 'x64-osx'
    # elif sys_platform.startswith('win32'):
    #     return '...-dynamic'
    else:
        return 'x64-linux'
