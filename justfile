#!/usr/bin/env -S just --justfile
#
# To run this script, you must have installed the Just command runner. Execute:
# $ cargo install just

setup:
    git config pull.rebase true
    git config branch.autoSetupRebase always
    cargo install typos-cli
    cargo install cocogitto
    cog install-hook --overwrite commit-msg
    @echo "Done"

self-update:
    cargo install just
