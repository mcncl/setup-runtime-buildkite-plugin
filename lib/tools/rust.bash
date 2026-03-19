#!/usr/bin/env bash

setup_rust() {
  local install_path="$1"

  if [ -z "$install_path" ]; then return; fi

  if [ -z "${CARGO_HOME:-}" ]; then
    export CARGO_HOME="${HOME}/.cargo"
    append_export CARGO_HOME "${HOME}/.cargo"
  fi

  mkdir -p "${CARGO_HOME}/bin"
  prepend_path "${CARGO_HOME}/bin"

  log_debug "CARGO_HOME=${CARGO_HOME}"
}

verify_rust() {
  rustc --version 2>/dev/null || true
}
