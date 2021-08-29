#!/usr/bin/env bash
set -e

# this commit is run as a commit-msg hook
REPO_DIR="$(git rev-parse --show-toplevel)"
HELP_URL="https://github.com/neovim/neovim/blob/master/CONTRIBUTING.md#commit-messages"
VIM_PATCH_CONFIG="$REPO_DIR/.github/workflows/commitlint.config_patch.js"
CONFIG="$REPO_DIR/.github/workflows/commitlint.config.js"

if grep 'vim-patch' "$1"; then
  if ! npx commitlint --edit --verbose --help-url "$HELP_URL" --config "$VIM_PATCH_CONFIG"; then
    exit 1
  fi
else
  if ! npx commitlint --edit --verbose --help-url "$HELP_URL" --config "$CONFIG"; then
    exit 1
  fi
fi

exit 0
