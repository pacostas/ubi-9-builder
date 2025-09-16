#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${PROG_DIR}/.." && pwd)"
readonly BIN_DIR="${ROOT_DIR}/.bin"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${PROG_DIR}/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${PROG_DIR}/.util/print.sh"

if [[ $BASH_VERSINFO -lt 4 ]]; then
  util::print::error "Before running this script please update Bash to v4 or higher (e.g. on OSX: \$ brew install bash)"
fi

function main() {
  local builder_toml_path=""
  local builder_image_ref=""

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      --builder-toml-path)
        builder_toml_path=${2}
        shift 2
        ;;

      --builder-image-ref)
        builder_image_ref=${2}
        shift 2
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        util::print::error "unknown argument \"${1}\""
    esac
  done


  if [ -z "$builder_toml_path" ]; then
    util::print::error "--builder-toml-path is required [Example: ./builders/builder/builder.toml]"
  fi

  if [ ! -f "$builder_toml_path" ]; then
    util::print::error "The provided --builder-toml-path does not exist or is not a file: $builder_toml_path"
  fi

  if [ -z "$builder_image_ref" ]; then
    util::print::error "--builder-image-ref is required [Example: index.docker.io/username/builder:tag or localhost:5000/builder:tag]"
  fi

  tools::install

  builder::publish "$builder_toml_path" "$builder_image_ref"
}

function usage() {
  cat <<-USAGE
publish.sh [OPTIONS]

  --builder-toml-path PATH          Path to the builder.toml file that defines the builder to be published, e.g. ./builders/builder/builder.toml
  --builder-image-ref  IMAGE_REF    Full image name of the registry to push the built builder to, e.g. index.docker.io/username/builder:tag or localhost:5000/builder:tag
  --help, -h                        Show this help message
USAGE
}

function builder::publish() {
  local builder_toml_path="$1"
  local builder_image_ref="$2"

  pack builder create "${builder_image_ref}" --config builder.toml --publish
  pack builder create-builder builder --config "$builder_toml_path" --pull-policy if-not-present

  # iterate over build_ref & run_ref, they will be the same length
  local len=${#build_ref[@]}
  for (( i=0; i<len; i++ )); do
    local br="${build_ref[$i]}"
    local rr="${run_ref[$i]}"
    args=(
      "--build-ref" "$br"
      "--run-ref" "$rr"
      "--build-archive" "$build_archive"
      "--run-archive" "$run_archive"
    )
    jam publish-stack "${args[@]}"
  done
}



main "${@:-}"
