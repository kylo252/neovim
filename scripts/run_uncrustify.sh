#!/usr/bin/env bash
set -eu

BASENAME="$(basename "${0}")"

usage() {
  echo "Run Uncrustify"
  echo
  echo "Usage:  ${BASENAME} [-h | -c | -l ]"
  echo
  echo "Options:"
  echo "    -h                 Show this message and exit."
  echo "    -c                 Can be used as a commit-hook [will perform both formatting and linting]"
  echo "    -l                 Use to lint the files modified in the last commit [github workflow]"
}

# commit-hook mode
function commit-hook() {
  for file in $(git diff --name-only --staged | grep -E '\.(c|h)$'); do
    if ! uncrustify --check -c contrib/uncrustify.cfg "$file"; then
      uncrustify -c contrib/uncrustify.cfg --replace --no-backup "$file"
      echo ">> Formatting was performed. You need to commit your files again"
      exit 1
    fi
    [ -f "$file".uncrustify ] && rm "$file".uncrustify
  done
}

function last-commit() {
  for file in $(git diff --name-only HEAD~1 | grep -E '\.(c|h)$'); do
    if ! uncrustify --check -c contrib/uncrustify.cfg "$file"; then
      echo ">> Formatting is required"
      exit 1
    fi
    [ -f "$file".uncrustify ] && rm "$file".uncrustify
  done
}

while getopts "hcl" opt; do
  case ${opt} in
    h)
      usage
      exit 0
      ;;
    c)
      commit-hook
      exit 0
      ;;
    l)
      last-commit
      exit 0
      ;;
    *)
      exit 1
      ;;
  esac
done

usage

# vim: et sw=2
