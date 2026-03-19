#!/usr/bin/env bash

# Tool dispatch layer.
#
# Sources individual tool files from lib/tools/ and dispatches
# setup/verify calls based on tool name. To add a new tool:
#
#   1. Create lib/tools/<name>.bash
#   2. Define setup_<name>() and verify_<name>()
#   3. Add a source line and (if needed) an alias in resolve_tool_name()

set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tools"

# shellcheck source=lib/tools/go.bash
source "${TOOLS_DIR}/go.bash"
# shellcheck source=lib/tools/java.bash
source "${TOOLS_DIR}/java.bash"
# shellcheck source=lib/tools/node.bash
source "${TOOLS_DIR}/node.bash"
# shellcheck source=lib/tools/python.bash
source "${TOOLS_DIR}/python.bash"
# shellcheck source=lib/tools/ruby.bash
source "${TOOLS_DIR}/ruby.bash"
# shellcheck source=lib/tools/rust.bash
source "${TOOLS_DIR}/rust.bash"

# Map alternative tool names to their canonical name.
resolve_tool_name() {
  local tool="$1"
  case "$tool" in
    golang)  echo "go"   ;;
    openjdk) echo "java" ;;
    nodejs)  echo "node" ;;
    *)       echo "$tool" ;;
  esac
}

# Dispatch post-install setup for a tool.
# Arguments: tool_name tool_version
tool_post_install() {
  local tool
  tool="$(resolve_tool_name "$1")"
  local version="$2"

  # Use the original tool name (not resolved alias) for mise lookup,
  # since mise knows the tool by its original name (e.g. "golang").
  local install_path
  install_path="$(run_mise where "${1}@${version}" 2>/dev/null || true)"

  local setup_fn="setup_${tool}"
  if type -t "$setup_fn" &>/dev/null; then
    "$setup_fn" "$install_path"
  else
    log_debug "No tool-specific setup for ${tool}"
  fi
}

# Print the active version of a tool for build-log verification.
# Arguments: tool_name
tool_verify() {
  local tool
  tool="$(resolve_tool_name "$1")"

  local verify_fn="verify_${tool}"
  if type -t "$verify_fn" &>/dev/null; then
    "$verify_fn"
  else
    log_debug "No verification command for ${tool}"
  fi
}
