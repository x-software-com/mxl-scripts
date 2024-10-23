#!/usr/bin/env python3
"""Script to setup the environment for MXL development"""

import os

from shared.mxl_env import setup_mxl_env

ROOTDIR = os.path.split(os.path.abspath(os.path.dirname(__file__)))[0]

if __name__ == '__main__':
    setup_mxl_env(ROOTDIR)
