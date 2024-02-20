"""Helper containing basic setup tasks"""

import os
import subprocess

def setup_git():
    """Setup git for development"""
    subprocess.run(['git', 'config', 'pull.rebase', 'true'], check = True)
    subprocess.run(['git', 'config', 'branch.autoSetupRebase', 'always'], check = True)


def install_cocogitto():
    """Install cocogitto for conventional commits and version bumping"""
    print("Install cocogitto...")
    subprocess.run(['cargo', 'install', 'cocogitto'], check = True)


def setup_cocogitto():
    """Setup cocogitto for development use"""
    print("Setup cocogitto...")
    subprocess.run(['cog', 'install-hook', '--overwrite', 'commit-msg'], check = True)


def install_just():
    """Install 'just' as a basic 'make' replacement to configure, build, package and run projects"""
    print("Install just...")
    subprocess.run(['cargo', 'install', 'just'], check = True)


def install_cargo_bundle_licenses():
    """Install cargo bundle-license to extract all crates licenses and the texts"""
    print("Install cargo bundle-licenses...")
    subprocess.run(['cargo', 'install', 'cargo-bundle-licenses'], check = True)


def install_cargo_version_util():
    """Install cargo version-util to extract the version of Cargo.toml"""
    print("Install cargo version-util...")
    subprocess.run(['cargo', 'install', 'cargo-version-util'], check = True)


def install_typos():
    """Install typos to check the repository for common typos"""
    print("Install typos...")
    subprocess.run(['cargo', 'install', 'typos-cli'], check = True)


def setup_tools(setup_for_ci):
    """Install and setup all tools"""
    res = subprocess.run(['gcc', '-dumpversion'], text = True, capture_output = True, check = False)
    if res.returncode != 0:
        raise res.stderr
    if res.stdout.strip().startswith('13'):
        os.environ["CC"] = "clang"

    if not setup_for_ci:
        setup_git()
    else:
        # Add the current directory as a safe directory to determine the current version number
        subprocess.run(['git', 'config', '--global', '--add', 'safe.directory', os.getcwd()], check = True)
    install_just()

    # Cargo third-party license helper:
    install_cargo_bundle_licenses()

    install_cargo_version_util()
    install_typos()

    install_cocogitto()
    if not setup_for_ci:
        setup_cocogitto()


def setup_write_mxl_env():
    """Write the MXL env file for VSCodium/VSCode to use the VCPKG libraries"""
    subprocess.run(['just', 'mxl-env'], check = True)
