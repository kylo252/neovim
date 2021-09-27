#!/usr/bin/env bash
set -eo pipefail

BASENAME="$(basename "${0}")"
REPO_ROOT=$(git rev-parse --show-toplevel)
BASE_SHA1="HEAD^!"
SHOULD_FIX=0

# TODO(kylo252): add a sanity-check for validating uncrustify's version
# probably something along the lines of
#
#   version=$(uncrustify --version)
#   supported=$(head -1 src/uncrustify.cfg)
#   if [[ $version =~ $supported ]]; then
#     echo 'please upgrade your version' && exit 1
#   fi

usage() {
  echo "Check files modified in the last (or specific) commit with Uncrustify"
  echo
  echo "Usage:  ${BASENAME} [-h | -f | -b ]"
  echo
  echo "Options:"
  echo "    -h, --help                Show this message and exit."
  echo "    -f, --fix                 Use to format the files modified in the last commit"
  echo "    -b, --base-sha            Base commit SHA1 [default: HEAD^!]"
}

function main() {
  parse_arguments "$@"
  while read -r file; do
    echo "Checking: $file"
    if ! uncrustify --check -c "${REPO_ROOT}/src/uncrustify.cfg" "$file" &>/dev/null; then
      if [ "$SHOULD_FIX" -gt 0 ]; then
        uncrustify -c "${REPO_ROOT}/src/uncrustify.cfg" --replace --no-backup "$file"
      else
        echo ">> Formatting is required"
        exit 1
      fi
    fi
    [ -f "$file".uncrustify ] && rm "$file".uncrustify
  done < <(
    git diff --name-only ${BASE_SHA1} -- ':src/nvim/*.c' ':src/nvim/*.h'
  )
}

function parse_arguments() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -b | --base-sha)
        BASE_SHA1="$2"
        shift # remove opt
        ;;
      -f | --fix)
        SHOULD_FIX=1
        ;;
      -h | --help)
        usage
        exit 0
        ;;
    esac
    shift
  done
}

main "$@"

# vim: et sw=2
