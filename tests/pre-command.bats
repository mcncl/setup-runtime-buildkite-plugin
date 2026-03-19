#!/usr/bin/env bats

setup() {
  export BUILDKITE_BUILD_CHECKOUT_PATH="$BATS_TEST_TMPDIR/checkout"
  export BUILDKITE_ENV_FILE="$BATS_TEST_TMPDIR/env"
  mkdir -p "$BUILDKITE_BUILD_CHECKOUT_PATH"
  touch "$BUILDKITE_ENV_FILE"

  # Stub out curl/tar so we never hit the network
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  mkdir -p "$BATS_TEST_TMPDIR/bin"

  # Create a fake mise binary
  FAKE_MISE_DIR="$BATS_TEST_TMPDIR/mise-data"
  mkdir -p "$FAKE_MISE_DIR/bin"
  cat > "$FAKE_MISE_DIR/bin/mise" <<'MISE'
#!/bin/bash
case "$1" in
  --version) echo "mise 2026.1.0" ;;
  install)   echo "installed $2" ;;
  use)       echo "using $3" ;;
  where)     echo "/fake/install/path" ;;
  env)
    echo "export PATH=/fake/shims:\$PATH"
    ;;
esac
MISE
  chmod +x "$FAKE_MISE_DIR/bin/mise"

  # Pre-set MISE_DATA_DIR so ensure_mise skips the download
  export MISE_DATA_DIR="$FAKE_MISE_DIR"
}

@test "installs explicitly configured tools" {
  export BUILDKITE_PLUGIN_SETUP_RUNTIME_TOOLS_0="go@1.22"
  export BUILDKITE_PLUGIN_SETUP_RUNTIME_TOOLS_1="node@20"

  run bash hooks/pre-command

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing configured tools"* ]]
  [[ "$output" == *"go@1.22"* ]]
  [[ "$output" == *"node@20"* ]]
}

@test "auto-detects tool-versions when present" {
  echo "go 1.22" > "$BUILDKITE_BUILD_CHECKOUT_PATH/.tool-versions"

  run bash hooks/pre-command

  [ "$status" -eq 0 ]
  [[ "$output" == *"Installing tools from repo config"* ]]
}

@test "skips auto-detect when disabled" {
  export BUILDKITE_PLUGIN_SETUP_RUNTIME_AUTO_DETECT="false"
  echo "go 1.22" > "$BUILDKITE_BUILD_CHECKOUT_PATH/.tool-versions"

  run bash hooks/pre-command

  [ "$status" -eq 0 ]
  [[ "$output" != *"Installing tools from repo config"* ]]
}

@test "skips auto-detect when no config files present" {
  run bash hooks/pre-command

  [ "$status" -eq 0 ]
  [[ "$output" != *"Installing tools from repo config"* ]]
}

@test "writes mise env vars to BUILDKITE_ENV_FILE" {
  run bash hooks/pre-command

  [ "$status" -eq 0 ]
  grep -q "MISE_DATA_DIR" "$BUILDKITE_ENV_FILE"
  grep -q "MISE_YES" "$BUILDKITE_ENV_FILE"
}
