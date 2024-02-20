#!/usr/bin/env python3
"""Print the VCPKG triplet for the current platform to stdout"""

from shared.triplet import triplet


def main():
    """Print the VCPKG triplet for the current platform to stdout"""
    print(triplet())


if __name__ == '__main__':
    main()
