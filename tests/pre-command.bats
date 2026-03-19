#!/usr/bin/env bats

setup() {
  export BUILDKITE_BUILD_CHECKOUT_PATH="$BATS_TEST_TMPDIR/checkout"
  export BUILDKITE_ENV_FILE="$BATS_TEST_TMPDIR/env"
  mkdir -p "$BUILDKITE_BUILD_CHECKOUT_PATH"
  touch "$BUILDKITE_ENV_FILE"

  # Create a fake mise binary
  FAKE_MISE_DIR="$BATS_TEST_TMPDIR/mise-data"
  mkdir -p "$FAKE_MISE_DIR/bin"
  cat > "$FAKE_MISE_DIR/bin/mise" <<'MISE'
#!/bin/bash
case "$1" in
  --version) echo "2026.3.9 linux-x64 (abc1234)" ;;
  install)   echo "installed $2" ;;
  use)       echo "using $3" ;;
  where)     echo "/fake/install/path" ;;
  env)       echo "export PATH=/fake/shims:\$PATH" ;;
  ls)        ;; # no output by default
esac
MISE
  chmod +x "$FAKE_MISE_DIR/bin/mise"

  # Point mise resolution to our fake and pin version so ensure_mise
  # finds the binary and skips the download entirely.
  export MISE_DATA_DIR="$FAKE_MISE_DIR"
  export BUILDKITE_PLUGIN_SETUP_RUNTIME_VERSION="2026.3.9"

  # Stub curl as a safety net — it should never be called with the
  # version pinned and the fake binary in place.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/curl" <<'CURL'
#!/bin/bash
echo "ERROR: unexpected curl call: $*" >&2
exit 1
CURL
  chmod +x "$BATS_TEST_TMPDIR/bin/curl"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
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

@test "runs post-install setup for auto-detected tools" {
  echo "go 1.22" > "$BUILDKITE_BUILD_CHECKOUT_PATH/.tool-versions"

  # Override the fake mise to return tool lines from ls --current
  cat > "$FAKE_MISE_DIR/bin/mise" <<'MISE'
#!/bin/bash
case "$1" in
  --version) echo "2026.3.9 linux-x64 (abc1234)" ;;
  install)   echo "installed $2" ;;
  use)       echo "using $3" ;;
  where)     echo "/fake/install/path" ;;
  env)       echo "export PATH=/fake/shims:\$PATH" ;;
  ls)        echo "go  1.22.5  /checkout/.tool-versions" ;;
esac
MISE
  chmod +x "$FAKE_MISE_DIR/bin/mise"

  run bash hooks/pre-command

  [ "$status" -eq 0 ]
  # GOROOT should be written to BUILDKITE_ENV_FILE by setup_go
  grep -q "GOROOT" "$BUILDKITE_ENV_FILE"
}

@test "deduplicates explicit and auto-detected tools" {
  echo "go 1.22" > "$BUILDKITE_BUILD_CHECKOUT_PATH/.tool-versions"
  export BUILDKITE_PLUGIN_SETUP_RUNTIME_TOOLS_0="go@1.22"

  cat > "$FAKE_MISE_DIR/bin/mise" <<'MISE'
#!/bin/bash
case "$1" in
  --version) echo "2026.3.9 linux-x64 (abc1234)" ;;
  install)   echo "installed $2" ;;
  use)       echo "using $3" ;;
  where)     echo "/fake/install/path" ;;
  env)       echo "export PATH=/fake/shims:\$PATH" ;;
  ls)        echo "go  1.22.5  /checkout/.tool-versions" ;;
esac
MISE
  chmod +x "$FAKE_MISE_DIR/bin/mise"

  run bash hooks/pre-command

  [ "$status" -eq 0 ]
  # GOROOT should appear exactly once — not duplicated
  [ "$(grep -c "GOROOT" "$BUILDKITE_ENV_FILE")" -eq 1 ]
}

@test "writes mise env vars to BUILDKITE_ENV_FILE" {
  run bash hooks/pre-command

  [ "$status" -eq 0 ]
  grep -q "MISE_DATA_DIR" "$BUILDKITE_ENV_FILE"
  grep -q "MISE_YES" "$BUILDKITE_ENV_FILE"
}
