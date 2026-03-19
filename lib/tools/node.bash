#!/usr/bin/env bash

setup_node() {
  local install_path="$1"

  if [ -z "$install_path" ]; then return; fi

  # Enable corepack so yarn/pnpm are available without separate install
  if [ -x "${install_path}/bin/corepack" ]; then
    "${install_path}/bin/corepack" enable 2>/dev/null || true
    log_debug "corepack enabled"
  fi
}

verify_node() {
  node --version 2>/dev/null || true
}
