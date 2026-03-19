#!/usr/bin/env bash

setup_python() {
  local install_path="$1"

  if [ -z "$install_path" ]; then return; fi

  # Prevent pip from installing outside a virtualenv by default in CI,
  # but don't override if the user has already set this.
  if [ -z "${PIP_REQUIRE_VIRTUALENV:-}" ]; then
    export PIP_REQUIRE_VIRTUALENV=0
    append_export PIP_REQUIRE_VIRTUALENV "0"
  fi

  log_debug "Python install path: ${install_path}"
}

verify_python() {
  python3 --version 2>/dev/null || python --version 2>/dev/null || true
}
