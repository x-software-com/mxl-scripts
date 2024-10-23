#!/usr/bin/env python3
"""Script to build VCPKG third party libraries"""

import argparse

from shared.vcpkg import setup_vcpkg


def setup():
    """Parse command line and call setup functions"""
    parser = argparse.ArgumentParser(description='Setup mxl environment')
    parser.add_argument('--project-name', dest='project', type=str, required=True, help='Name of the project')
    parser.add_argument('--vcpkg-version', dest='version', type=str, required=True, help='Version of vcpkg to build')
    options = parser.parse_args()

    setup_vcpkg(options.project, options.version)


if __name__ == "__main__":
    setup()
