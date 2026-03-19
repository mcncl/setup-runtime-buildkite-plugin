# Setup Runtime Buildkite Plugin

[![Build status](https://badge.buildkite.com/ba96a554196ea452889ed5844532163f7c1b5a637d2a50f00d.svg)](https://buildkite.com/no-assembly/setup-runtime-buildkite-plugin)

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) to install and configure language runtimes and tools for your build steps.

Specify the tools you need directly in your pipeline YAML — the plugin installs them, configures the environment (`GOROOT`, `JAVA_HOME`, corepack, etc.), and prints the active versions to the build log. It can also auto-detect tools from `mise.toml`, `.mise.toml`, or `.tool-versions` in your repository.

Uses [mise](https://mise.jdx.dev/) under the hood for tool installation and version management.

## Examples

### Inline tools

```yaml
steps:
  - label: ":golang: Test"
    plugins:
      - buildkite/setup-runtime#v1.0.0:
          tools:
            - "go@1.22"
    command: go test ./...
```

### Multiple tools

```yaml
steps:
  - label: ":node: Build"
    plugins:
      - buildkite/setup-runtime#v1.0.0:
          tools:
            - "node@20"
            - "python@3.12"
    command: npm run build
```

### Auto-detect from repo config

If your repository contains a `mise.toml`, `.mise.toml`, or `.tool-versions`, the plugin picks it up automatically:

```yaml
steps:
  - label: ":wrench: Build"
    plugins:
      - buildkite/setup-runtime#v1.0.0: ~
    command: make build
```

### Monorepo

```yaml
steps:
  - label: ":golang: Test backend"
    plugins:
      - buildkite/setup-runtime#v1.0.0:
          tools:
            - "go@1.22"
          dir: backend
    command: go test ./...
```

### Inline tools with repo config

Explicit tools are installed first, then repo config is auto-detected. Repo-level versions take precedence in the working directory:

```yaml
steps:
  - label: ":test_tube: Integration"
    plugins:
      - buildkite/setup-runtime#v1.0.0:
          tools:
            - "node@20"
    command: make integration
```

### Hosted agent cache volumes

```yaml
cache: ".buildkite/cache-volume"

steps:
  - label: ":golang: Test"
    plugins:
      - buildkite/setup-runtime#v1.0.0:
          tools:
            - "go@1.22"
    command: go test ./...
```

On Buildkite hosted agents, the plugin automatically detects the cache volume and uses `/cache/bkcache/mise` as `MISE_DATA_DIR` — no `cache-dir` config needed.

## Configuration

### `tools` (array of strings, optional)

Tools to install in `tool@version` format. These are installed and activated globally for the step regardless of repo config files.

### `auto-detect` (boolean, default: `true`)

When `true`, the plugin also runs `mise install` from `mise.toml`, `.mise.toml`, or `.tool-versions` if present in the working directory.

### `version` (string, default: `latest`)

Version of mise to install (e.g. `2026.2.11`).

### `dir` (string, optional)

Directory where `mise install` and `mise env` run. Defaults to the checkout directory. Useful for monorepos where tools are defined in a subdirectory.

### `cache-dir` (string, optional)

Directory to use for `MISE_DATA_DIR`. On hosted agents with an attached cache volume this is detected automatically. Mainly useful on self-hosted agents with a persistent disk.

## Tool-specific environment setup

The plugin automatically configures tool-specific environment variables after installation:

| Tool | Environment setup |
|------|-------------------|
| `go` | Sets `GOROOT`, sets `GOPATH` if unset, prepends `GOPATH/bin` to PATH |
| `java` | Sets `JAVA_HOME` (handles macOS `Contents/Home` layout) |
| `node` | Enables corepack (yarn/pnpm available without separate install) |
| `python` | Sets `PIP_REQUIRE_VIRTUALENV=0` if unset |
| `ruby` | Sets `GEM_HOME` if unset, prepends `GEM_HOME/bin` to PATH |
| `rust` | Sets `CARGO_HOME` if unset, prepends `CARGO_HOME/bin` to PATH |

All configured tools print their active version to the build log for verification.

## Development

Run plugin checks locally:

```bash
docker run --rm -v "$PWD:/plugin" -w /plugin buildkite/plugin-linter --id buildkite/setup-runtime --path /plugin
docker run --rm -t -v "$PWD:/plugin" buildkite/plugin-tester:latest
```

## License

MIT License. See [LICENSE](LICENSE) for details.
