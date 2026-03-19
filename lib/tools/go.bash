#!/usr/bin/env bash

setup_go() {
  local install_path="$1"

  if [ -z "$install_path" ]; then return; fi

  export GOROOT="$install_path"
  append_export GOROOT "$install_path"

  if [ -z "${GOPATH:-}" ]; then
    export GOPATH="${HOME}/go"
    append_export GOPATH "${HOME}/go"
  fi

  mkdir -p "${GOPATH}/bin"
  prepend_path "${GOPATH}/bin"

  log_debug "GOROOT=${GOROOT} GOPATH=${GOPATH}"
}

verify_go() {
  go version 2>/dev/null || true
}
