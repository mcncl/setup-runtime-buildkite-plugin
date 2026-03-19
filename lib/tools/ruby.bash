#!/usr/bin/env bash

setup_ruby() {
  local install_path="$1"

  if [ -z "$install_path" ]; then return; fi

  if [ -z "${GEM_HOME:-}" ]; then
    export GEM_HOME="${HOME}/.gem"
    append_export GEM_HOME "${HOME}/.gem"
  fi

  mkdir -p "${GEM_HOME}/bin"
  prepend_path "${GEM_HOME}/bin"

  log_debug "GEM_HOME=${GEM_HOME}"
}

verify_ruby() {
  ruby --version 2>/dev/null || true
}
