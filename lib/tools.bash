#!/bin/bash

# Tool-specific post-install environment setup.
#
# After mise installs a tool, some runtimes need extra env vars (GOROOT,
# JAVA_HOME, etc.) or verification steps.  This file centralises that
# per-tool knowledge — the thing that makes setup-runtime more than a
# thin mise wrapper.

set -euo pipefail

# Dispatch post-install setup for a tool.
# Arguments: tool_name  tool_version
tool_post_install() {
  local tool="$1"
  local version="$2"

  # Resolve the install path from mise
  local install_path
  install_path="$(run_mise where "${tool}@${version}" 2>/dev/null || true)"

  case "$tool" in
    go|golang)   _setup_go   "$install_path" "$version" ;;
    java|openjdk) _setup_java "$install_path" "$version" ;;
    python)      _setup_python "$install_path" "$version" ;;
    node|nodejs) _setup_node  "$install_path" "$version" ;;
    ruby)        _setup_ruby  "$install_path" "$version" ;;
    *)           log_debug "No tool-specific setup for ${tool}" ;;
  esac
}

# Print the active version of a tool for build-log verification.
# Arguments: tool_name
tool_verify() {
  local tool="$1"

  case "$tool" in
    go|golang)    go version    2>/dev/null || true ;;
    java|openjdk) java -version 2>&1 | head -1 || true ;;
    python)       python3 --version 2>/dev/null || python --version 2>/dev/null || true ;;
    node|nodejs)  node --version 2>/dev/null || true ;;
    ruby)         ruby --version 2>/dev/null || true ;;
    rust)         rustc --version 2>/dev/null || true ;;
    *)            log_debug "No verification command for ${tool}" ;;
  esac
}

# ---------------------------------------------------------------------------
# Per-tool setup functions
# ---------------------------------------------------------------------------

_setup_go() {
  local install_path="$1" version="$2"

  if [ -z "$install_path" ]; then return; fi

  export GOROOT="$install_path"
  append_export GOROOT "$install_path"

  if [ -z "${GOPATH:-}" ]; then
    export GOPATH="${HOME}/go"
    append_export GOPATH "${HOME}/go"
    mkdir -p "${GOPATH}/bin"
  fi

  log_debug "GOROOT=${GOROOT} GOPATH=${GOPATH}"
}

_setup_java() {
  local install_path="$1" version="$2"

  if [ -z "$install_path" ]; then return; fi

  # On macOS, the actual home is inside Contents/Home
  if [ -d "${install_path}/Contents/Home" ]; then
    install_path="${install_path}/Contents/Home"
  fi

  export JAVA_HOME="$install_path"
  append_export JAVA_HOME "$install_path"
  log_debug "JAVA_HOME=${JAVA_HOME}"
}

_setup_python() {
  local install_path="$1" version="$2"

  if [ -z "$install_path" ]; then return; fi

  # Prevent pip from installing outside a virtualenv by default in CI,
  # but don't override if the user has already set this.
  if [ -z "${PIP_REQUIRE_VIRTUALENV:-}" ]; then
    export PIP_REQUIRE_VIRTUALENV=0
    append_export PIP_REQUIRE_VIRTUALENV "0"
  fi

  log_debug "Python install path: ${install_path}"
}

_setup_node() {
  local install_path="$1" version="$2"

  if [ -z "$install_path" ]; then return; fi

  # Enable corepack so yarn/pnpm are available without separate install
  if [ -x "${install_path}/bin/corepack" ]; then
    "${install_path}/bin/corepack" enable 2>/dev/null || true
    log_debug "corepack enabled"
  fi
}

_setup_ruby() {
  local install_path="$1" version="$2"

  if [ -z "$install_path" ]; then return; fi

  if [ -z "${GEM_HOME:-}" ]; then
    export GEM_HOME="${HOME}/.gem"
    append_export GEM_HOME "${HOME}/.gem"
    mkdir -p "${GEM_HOME}/bin"
  fi

  log_debug "GEM_HOME=${GEM_HOME}"
}
