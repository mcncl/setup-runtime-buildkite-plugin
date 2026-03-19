#!/bin/bash

# Shared utility functions for the setup-runtime plugin

set -euo pipefail

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

log_info() {
  echo "[setup-runtime] $*"
}

log_error() {
  echo "[setup-runtime] $*" >&2
}

log_debug() {
  if [ "${BUILDKITE_PLUGIN_SETUP_RUNTIME_DEBUG:-false}" = "true" ]; then
    echo "[setup-runtime][debug] $*" >&2
  fi
}

# ---------------------------------------------------------------------------
# Plugin config helpers
# ---------------------------------------------------------------------------

plugin_cfg() {
  local key="$1"
  local normalized
  normalized="$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]' | tr '-' '_')"
  local var_name="BUILDKITE_PLUGIN_SETUP_RUNTIME_${normalized}"
  printf '%s' "${!var_name:-}"
}

plugin_cfg_default() {
  local value
  value="$(plugin_cfg "$1")"
  if [ -n "$value" ]; then
    printf '%s' "$value"
  else
    printf '%s' "$2"
  fi
}

# ---------------------------------------------------------------------------
# Mise data-dir resolution (mirrors mise-buildkite-plugin logic)
# ---------------------------------------------------------------------------

resolve_mise_dir() {
  if [ -n "${MISE_DATA_DIR:-}" ]; then
    MISE_DIR="$MISE_DATA_DIR"
    return
  fi

  local cache_dir_cfg
  cache_dir_cfg="$(plugin_cfg cache-dir)"
  if [ -n "$cache_dir_cfg" ]; then
    MISE_DIR="$cache_dir_cfg"
    return
  fi

  local hosted_root="${MISE_HOSTED_CACHE_VOLUME_ROOT:-/cache/bkcache}"
  if [ "${BUILDKITE_COMPUTE_TYPE:-self-hosted}" = "hosted" ] \
     && [ -d "$hosted_root" ] && [ -w "$hosted_root" ]; then
    MISE_DIR="${hosted_root}/mise"
    return
  fi

  MISE_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/mise"
}

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

detect_platform() {
  local os arch musl_suffix=""

  case "$(uname -s)" in
    Linux)  os="linux" ;;
    Darwin) os="macos" ;;
    *)
      log_error "Unsupported OS: $(uname -s)"
      exit 1
      ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64)    arch="x64"   ;;
    arm64|aarch64)   arch="arm64" ;;
    armv7l|armv7)    arch="armv7" ;;
    *)
      log_error "Unsupported architecture: $(uname -m)"
      exit 1
      ;;
  esac

  if [ "$os" = linux ] && command -v ldd >/dev/null 2>&1; then
    if ldd --version 2>&1 | grep -qi musl; then
      musl_suffix="-musl"
    fi
  fi

  printf '%s' "${os}-${arch}${musl_suffix}"
}

# ---------------------------------------------------------------------------
# Mise installation
# ---------------------------------------------------------------------------

install_mise() {
  local version="$1"
  local platform="$2"
  local url="https://github.com/jdx/mise/releases/download/v${version}/mise-v${version}-${platform}.tar.gz"
  local archive extracted

  archive="$(mktemp)"
  extracted="$(mktemp -d)"

  log_info "Downloading mise v${version} for ${platform}"

  (
    set -euo pipefail
    trap 'rm -f "$archive"; rm -rf "$extracted"' EXIT

    curl -fsSL "$url" > "$archive"
    tar -xzf "$archive" -C "$extracted"

    mkdir -p "$MISE_BIN"
    if [ -x "$extracted/mise/bin/mise" ]; then
      mv "$extracted/mise/bin/mise" "$MISE_BINARY"
    elif [ -x "$extracted/bin/mise" ]; then
      mv "$extracted/bin/mise" "$MISE_BINARY"
    else
      log_error "Could not find mise binary in archive"
      exit 1
    fi
  )
}

ensure_mise() {
  local required_version_raw
  required_version_raw="$(plugin_cfg_default version latest)"

  resolve_mise_dir
  MISE_BIN="${MISE_DIR}/bin"
  MISE_BINARY="${MISE_BIN}/mise"

  local version
  if [ "$required_version_raw" = latest ]; then
    version="$(curl -fsSL https://mise.jdx.dev/VERSION | tr -d '\r\n')"
  else
    version="${required_version_raw#v}"
  fi
  version="${version#v}"

  local current=""
  if [ -x "$MISE_BINARY" ]; then
    current="$("$MISE_BINARY" --version 2>/dev/null | awk '{print $2}' | tr -d 'v')"
  fi

  if [ -z "$current" ] || [ "$current" != "$version" ]; then
    install_mise "$version" "$(detect_platform)"
  fi

  log_info "mise $(run_mise --version)"
}

# ---------------------------------------------------------------------------
# Run mise with consistent env
# ---------------------------------------------------------------------------

run_mise() {
  local mise_env=(
    "MISE_DATA_DIR=$MISE_DIR"
    "MISE_TRUSTED_CONFIG_PATHS=${WORKING_DIRECTORY:-/}"
    "MISE_YES=1"
    "PATH=$MISE_BIN:$PATH"
  )

  env "${mise_env[@]}" "$MISE_BINARY" "$@"
}

# ---------------------------------------------------------------------------
# BUILDKITE_ENV_FILE helpers
# ---------------------------------------------------------------------------

append_export() {
  local name="$1" value="$2"
  printf 'export %s=%q\n' "$name" "$value" >> "$BUILDKITE_ENV_FILE"
}

apply_mise_env() {
  local mise_env_file
  mise_env_file="$(mktemp)"

  run_mise env --shell bash | tee -a "$BUILDKITE_ENV_FILE" > "$mise_env_file"

  # shellcheck disable=SC1090
  . "$mise_env_file"
  rm -f "$mise_env_file"
}
