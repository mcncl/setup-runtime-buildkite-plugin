#!/usr/bin/env bash

setup_java() {
  local install_path="$1"

  if [ -z "$install_path" ]; then return; fi

  # On macOS, the actual home is inside Contents/Home
  if [ -d "${install_path}/Contents/Home" ]; then
    install_path="${install_path}/Contents/Home"
  fi

  export JAVA_HOME="$install_path"
  append_export JAVA_HOME "$install_path"
  log_debug "JAVA_HOME=${JAVA_HOME}"
}

verify_java() {
  java -version 2>&1 | head -1 || true
}
