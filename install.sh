#!/bin/sh
set -eu

REPO="izhiwen/AiPlus_StarWeaver"
# Pre-initialize VERSION so `set -eu` does not bomb when the `gh` branch
# is skipped (fresh Linux box without GitHub CLI). Fixes upstream issue
# izhiwen/AiPlus#1.
VERSION=""
if [ -n "${AIPLUS_VERSION:-}" ]; then
  VERSION="$AIPLUS_VERSION"
else
  if command -v gh >/dev/null 2>&1; then
    VERSION=$(gh api repos/$REPO/releases/latest --jq .tag_name 2>/dev/null || echo "")
  fi
  if [ -z "$VERSION" ] && command -v curl >/dev/null 2>&1; then
    VERSION=$(curl -fsSL https://api.github.com/repos/$REPO/releases/latest 2>/dev/null \
      | grep -m1 '"tag_name"' \
      | sed 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/' \
      || echo "")
  fi
  VERSION="${VERSION:-v0.7.23}"  # fallback if both lookups fail (last-known-good)
fi
INSTALL_DIR="${AIPLUS_INSTALL_DIR:-$HOME/.local/bin}"
DRY_RUN=0
# P1.7: optional auto-register MCP server with installed runtimes.
# Values: "" (interactive prompt if tty), "yes" (silent register),
# "no" (silent skip).
REGISTER_MCP="${AIPLUS_REGISTER_MCP:-}"

usage() {
  cat <<'USAGE'
Install the aiplus and mother commands (same binary, two entry points).

Usage:
  sh install.sh [--dry-run] [--register-mcp | --no-register-mcp]

Environment:
  AIPLUS_VERSION       Release version to install, default latest GitHub release
  AIPLUS_INSTALL_DIR   Install directory, default $HOME/.local/bin
  AIPLUS_REGISTER_MCP  "yes" / "no" — same as flags, but settable from CI etc.
  AIPLUS_BASE_URL      Override release asset base URL for local demos/tests

Flags:
  --dry-run             Print what would happen without writing
  --register-mcp        After install, run `aiplus mcp-register` for any
                        detected runtime (codex / claude / opencode)
  --no-register-mcp     Skip the MCP registration prompt entirely
  -h, --help            Show this help

The installer downloads a GitHub Release asset, verifies checksums.txt, and
installs the aiplus binary plus aiplus-token-cost when present in the archive.
When the archive also carries the aiplus-gate-shim binary (v0.7.23+ releases),
it is staged at <prefix>/libexec/aiplus-shim/v<version>/cargo (staged only, no
symlink is created here); the activating `cargo` symlink is created later by
`aiplus gate --install`. Older archives without the shim are installed exactly
as before (the shim step is skipped, never an error).
It does not edit shell profiles, require sudo, install project modules, upload
data, collect telemetry, or modify global Codex/Claude Code/OpenCode config.

Supported platforms (auto-detected by uname):
  Darwin arm64 / aarch64           macOS Apple Silicon
  Windows x86_64                   Use install.ps1 instead of this script:
                                     iwr -useb https://raw.githubusercontent.com/$REPO/main/install.ps1 | iex
  Linux / Intel Mac / Windows ARM   Build from source:
                                     cargo build --release -p aiplus-cli
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --register-mcp)
      REGISTER_MCP=yes
      ;;
    --no-register-mcp)
      REGISTER_MCP=no
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR required command not found: $1" >&2
    exit 1
  fi
}

detect_asset() {
  os="$(uname -s)"
  arch="$(uname -m)"
  case "$os:$arch" in
    Darwin:arm64|Darwin:aarch64)
      echo "aiplus-aarch64-apple-darwin.tar.gz"
      ;;
    *)
      echo "ERROR no verified AiPlus $VERSION binary asset for: $os $arch" >&2
      echo "Supported pre-built platforms (v0.6.6+): Apple Silicon Mac (Darwin arm64) and Intel Windows (use install.ps1)." >&2
      echo "Intel Mac / Linux / Windows ARM: not supported — build from source: clone https://github.com/$REPO and run 'cargo build --release -p aiplus-cli'." >&2
      exit 1
      ;;
  esac
}

sha256_verify() {
  checksums="$1"
  asset="$2"
  asset_name="$(basename "$asset")"
  expected="$(grep "  $asset_name\$" "$checksums" || true)"
  if [ -z "$expected" ]; then
    echo "ERROR checksum not found for $asset_name" >&2
    exit 1
  fi
  printf '%s\n' "$expected" > "$TMP_DIR/asset.sha256"
  if command -v shasum >/dev/null 2>&1; then
    (cd "$(dirname "$asset")" && shasum -a 256 -c "$TMP_DIR/asset.sha256")
  elif command -v sha256sum >/dev/null 2>&1; then
    (cd "$(dirname "$asset")" && sha256sum -c "$TMP_DIR/asset.sha256")
  else
    echo "ERROR shasum or sha256sum is required for checksum verification" >&2
    exit 1
  fi
}

postprocess_macos_binary() {
  path="$1"
  label="$2"
  if [ "$(uname -s)" != "Darwin" ] || [ ! -f "$path" ]; then
    return 0
  fi

  if command -v xattr >/dev/null 2>&1; then
    if xattr -c "$path" >/dev/null 2>&1; then
      echo "MACOS_POSTPROCESS_XATTR=cleared target=$label"
    else
      echo "MACOS_POSTPROCESS_XATTR=WARN target=$label reason=xattr_failed" >&2
    fi
  else
    echo "MACOS_POSTPROCESS_XATTR=SKIP target=$label reason=xattr_not_found" >&2
  fi

  if ! command -v codesign >/dev/null 2>&1; then
    echo "MACOS_POSTPROCESS_CODESIGN=SKIP target=$label reason=codesign_not_found hint='install Xcode Command Line Tools or run xcode-select --install'" >&2
    return 0
  fi

  codesign --remove-signature "$path" >/dev/null 2>&1 || true
  if codesign --force --sign - --options runtime "$path" >/dev/null 2>&1; then
    echo "MACOS_POSTPROCESS_CODESIGN=adhoc_runtime target=$label"
    return 0
  fi

  echo "MACOS_POSTPROCESS_CODESIGN=WARN target=$label reason=codesign_failed" >&2
  return 1
}

# ─────────────────────────────────────────────────────────────────────
# Gate shim (transparent build gate, standalone-install PR#3).
# v0.7.23+ release tarballs carry an `aiplus-gate-shim` binary at the
# archive top level, next to aiplus / aiplus-token-cost (PR #347). When
# present, install.sh only STAGES it at the version-pinned libexec path
# <prefix>/libexec/aiplus-shim/v<version>/cargo (design doc
# docs/proposals/gate-shim-standalone-install-phase-a.md §2.1.1 + §3.2).
# The activating `cargo` symlink is the responsibility of
# `aiplus gate --install` (#349 Path 2); this installer never writes
# $INSTALL_DIR/cargo.
# Older archives (<= v0.7.22) do not contain the shim: that is expected,
# and this whole section is a clean SKIP for them. For v0.7.23+ archives,
# the shim is expected to be present, so a missing shim is unexpected
# and the echo below emits WARN instead of "expected" (fail-open, never
# fatal for the aiplus install itself). The shim is an enhancement,
# not a prerequisite — every failure path below warns and returns 0 so
# the aiplus install itself never fails because of the shim (fail-open).
# ─────────────────────────────────────────────────────────────────────
install_gate_shim() {
  shim_src="$1"
  if [ -z "$shim_src" ] || [ ! -f "$shim_src" ]; then
    # Version-aware: v0.7.0 – v0.7.22 archives do not carry the shim
    # (expected, clean SKIP for that whole range); v0.7.23+ archives
    # SHOULD carry it, so a missing shim is a WARN (not a fatal — the
    # aiplus install itself succeeds; the user just won't have the
    # cargo build gate). The case glob covers v0.7.[0-9] (single-digit
    # minors 0-9), v0.7.1[0-9] (10-19), and v0.7.2[012] (20-22); any
    # unrecognised future version falls into the WARN branch and
    # surfaces the gap instead of silently skipping.
    case "$VERSION" in
      v0.7.[0-9]|v0.7.1[0-9]|v0.7.2[012])
        echo "GATE_SHIM=SKIP reason=not_in_archive note='expected: this release ($VERSION) does not carry aiplus-gate-shim (shim first shipped in v0.7.23); aiplus install is complete; cargo build gate is unavailable on v0.7.22 and earlier'"
        ;;
      *)
        echo "GATE_SHIM=WARN reason=not_in_archive note='unexpected for v0.7.23+ releases: archive should carry aiplus-gate-shim but does not — aiplus itself installed; cargo build gate will be inactive until a complete archive is installed'"
        ;;
    esac
    return 0
  fi

  # Sanity-check the extracted shim before letting it near PATH: a real
  # shim binary is a compiled Rust executable well above 50KB; anything
  # smaller is truncated/corrupt and must not become the `cargo` symlink
  # target.
  shim_size="$(wc -c < "$shim_src" | tr -d '[:space:]')"
  if [ -z "$shim_size" ] || [ "$shim_size" -le 51200 ]; then
    echo "GATE_SHIM=WARN reason=sanity_size_failed size=${shim_size:-0}B floor=51201B action=skip_shim_install" >&2
    return 0
  fi

  # Path-encoded version layout (design doc §3.2): the binary is staged at
  # a version-pinned libexec path. `aiplus gate --install` later points the
  # activating symlink here; only that symlink moves across upgrades.
  shim_dir="$(dirname "$INSTALL_DIR")/libexec/aiplus-shim/v${VERSION#v}"
  shim_dest="$shim_dir/cargo"

  if ! mkdir -p "$shim_dir" 2>/dev/null; then
    echo "GATE_SHIM=WARN reason=libexec_not_writable dir=$shim_dir action=skip_shim_install hint='aiplus itself installed fine; create the dir manually and re-run to add the shim'" >&2
    return 0
  fi
  if ! cp "$shim_src" "$shim_dest" 2>/dev/null || ! chmod 755 "$shim_dest" 2>/dev/null; then
    echo "GATE_SHIM=WARN reason=copy_failed dest=$shim_dest action=skip_shim_install" >&2
    return 0
  fi

  # Same quarantine/stale-signature postprocess as the main binaries;
  # never fatal for the shim.
  postprocess_macos_binary "$shim_dest" "aiplus-gate-shim" || true

  if [ ! -x "$shim_dest" ]; then
    echo "GATE_SHIM=WARN reason=not_executable_after_install dest=$shim_dest action=skip_stage" >&2
    return 0
  fi

  # install.sh only STAGES the shim at the version-pinned libexec path.
  # The activating `cargo` symlink in $INSTALL_DIR is created later by
  # `aiplus gate --install` (#349 Path 2); this installer never writes
  # $INSTALL_DIR/cargo.
  echo "GATE_SHIM=STAGED shim=$shim_dest note='run aiplus gate --install to activate the cargo build gate'"
  echo "installed=$shim_dest"
  return 0
}

need_cmd uname
need_cmd mktemp
need_cmd tar
need_cmd chmod

if command -v curl >/dev/null 2>&1; then
  fetch() {
    curl -fsSL "$1" -o "$2"
  }
elif command -v wget >/dev/null 2>&1; then
  fetch() {
    wget -q "$1" -O "$2"
  }
else
  echo "ERROR curl or wget is required" >&2
  exit 1
fi

ASSET="$(detect_asset)"
BASE_URL="${AIPLUS_BASE_URL:-https://github.com/$REPO/releases/download/$VERSION}"
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

echo "AiPlus installer"
echo "version=$VERSION"
echo "asset=$ASSET"
echo "install_dir=$INSTALL_DIR"
echo "writes=$INSTALL_DIR/aiplus"
echo "writes=$INSTALL_DIR/aiplus-token-cost"
echo "writes=$INSTALL_DIR/mother (symlink to aiplus — Mother product entry point)"
# Shim staging path = $(dirname $INSTALL_DIR)/libexec/aiplus-shim/v<version>/cargo —
# one level up from $INSTALL_DIR (e.g. ~/.local/libexec/... not ~/.local/bin/libexec/...).
# The dirname is load-bearing: $INSTALL_DIR/libexec/... never exists on disk.
echo "writes=$(dirname "$INSTALL_DIR")/libexec/aiplus-shim/v<version>/cargo (staged gate-shim, only when the archive carries aiplus-gate-shim)"
echo "shell_profile_edits=none"
echo "telemetry=none"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "DRY_RUN=YES"
  echo "download=$BASE_URL/$ASSET"
  echo "checksums=$BASE_URL/checksums.txt"
  exit 0
fi

fetch "$BASE_URL/checksums.txt" "$TMP_DIR/checksums.txt"
fetch "$BASE_URL/$ASSET" "$TMP_DIR/$ASSET"
sha256_verify "$TMP_DIR/checksums.txt" "$TMP_DIR/$ASSET"

mkdir -p "$TMP_DIR/extract"
case "$ASSET" in
	  *.tar.gz)
	    tar -xzf "$TMP_DIR/$ASSET" -C "$TMP_DIR/extract"
	    BIN="$TMP_DIR/extract/aiplus"
	    TOKEN_COST_BIN="$TMP_DIR/extract/aiplus-token-cost"
	    if [ ! -f "$BIN" ]; then
	      BIN="$(find "$TMP_DIR/extract" -type f -name aiplus | head -n 1)"
	    fi
	    if [ ! -f "$TOKEN_COST_BIN" ]; then
	      TOKEN_COST_BIN="$(find "$TMP_DIR/extract" -type f -name aiplus-token-cost | head -n 1)"
	    fi
	    SHIM_BIN="$TMP_DIR/extract/aiplus-gate-shim"
	    if [ ! -f "$SHIM_BIN" ]; then
	      SHIM_BIN="$(find "$TMP_DIR/extract" -maxdepth 1 -type f -name aiplus-gate-shim | head -n 1)"
	    fi
	    ;;
	  *.zip)
	    need_cmd unzip
	    unzip -q "$TMP_DIR/$ASSET" -d "$TMP_DIR/extract"
	    BIN="$TMP_DIR/extract/aiplus.exe"
	    TOKEN_COST_BIN="$TMP_DIR/extract/aiplus-token-cost.exe"
	    if [ ! -f "$BIN" ]; then
	      BIN="$(find "$TMP_DIR/extract" -type f -name aiplus.exe | head -n 1)"
	    fi
	    if [ ! -f "$TOKEN_COST_BIN" ]; then
	      TOKEN_COST_BIN="$(find "$TMP_DIR/extract" -type f -name aiplus-token-cost.exe | head -n 1)"
	    fi
	    # The Windows zip carries aiplus-gate-shim.exe for checksum/parity
	    # only (PR #347 M1) — install.sh is Unix-only, so never install it.
	    SHIM_BIN=""
	    ;;
  *)
    echo "ERROR unsupported asset extension: $ASSET" >&2
    exit 1
    ;;
esac

if [ ! -f "$BIN" ]; then
  echo "ERROR release archive did not contain aiplus binary" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
chmod 755 "$BIN"
cp "$BIN" "$INSTALL_DIR/aiplus"
chmod 755 "$INSTALL_DIR/aiplus"
# Mother: same binary as aiplus, different entry point (checks argv[0]).
# A symlink is sufficient — is_mother_invocation() in main.rs reads the
# invoked name, not the binary path.
ln -sf aiplus "$INSTALL_DIR/mother" 2>/dev/null || cp "$INSTALL_DIR/aiplus" "$INSTALL_DIR/mother"
chmod 755 "$INSTALL_DIR/mother"
if [ -n "${TOKEN_COST_BIN:-}" ] && [ -f "$TOKEN_COST_BIN" ]; then
  chmod 755 "$TOKEN_COST_BIN"
  cp "$TOKEN_COST_BIN" "$INSTALL_DIR/aiplus-token-cost"
  chmod 755 "$INSTALL_DIR/aiplus-token-cost"
  TOKEN_COST_INSTALLED=1
else
  TOKEN_COST_INSTALLED=0
fi

# macOS 26.x can SIGKILL release binaries after archive extraction if
# quarantine or stale linker signatures survive install. Clear extended
# attributes, remove any stale signature, then apply an ad-hoc hardened
# runtime signature to the installed file. The operation is idempotent and
# intentionally runs after copy so it fixes the exact binary users execute.
MACOS_POSTPROCESS_FAILED=0
postprocess_macos_binary "$INSTALL_DIR/aiplus" "aiplus" || MACOS_POSTPROCESS_FAILED=1
if [ -f "$INSTALL_DIR/aiplus-token-cost" ]; then
  postprocess_macos_binary "$INSTALL_DIR/aiplus-token-cost" "aiplus-token-cost" || true
fi
if [ "$MACOS_POSTPROCESS_FAILED" -eq 1 ]; then
  echo "MACOS_POSTPROCESS_STATUS=WARN target=aiplus reason=postprocess_failed_smoke_will_verify" >&2
fi

# Post-install smoke test: make sure the copied binary can actually run.
SMOKE_EXIT=0
SMOKE_OUTPUT="$("$INSTALL_DIR/aiplus" --version 2>&1)" || SMOKE_EXIT=$?
if [ "$SMOKE_EXIT" -ne 0 ]; then
  echo "SMOKE_FAIL=exit=$SMOKE_EXIT output=$SMOKE_OUTPUT" >&2
  echo "INSTALL_STATUS=FAIL" >&2
  echo "ERROR: installed binary at $INSTALL_DIR/aiplus failed --version smoke test." >&2
  echo "ERROR: this may indicate (a) macOS Gatekeeper rejection, (b) corrupted download," >&2
  echo "ERROR: (c) missing system library, or (d) platform mismatch." >&2
  echo "ERROR: see https://github.com/izhiwen/AiPlus/issues for help." >&2
  exit 1
fi
echo "SMOKE_PASS=version=$SMOKE_OUTPUT"

echo "INSTALL_STATUS=PASS"
echo "installed=$INSTALL_DIR/aiplus"
if [ "$TOKEN_COST_INSTALLED" -eq 1 ]; then
  echo "installed=$INSTALL_DIR/aiplus-token-cost"
else
  echo "OPTIONAL_NOTICE=aiplus-token-cost not found in archive; installed aiplus only"
fi

# Gate shim install runs only after the main binary passed its smoke test,
# so a broken aiplus install never leaves a half-installed shim behind.
install_gate_shim "${SHIM_BIN:-}"

# Optional-feature notice (Linux only): the aiplus binary statically links
# libdbus (vendored in v0.5.11+), so it RUNS fine on any Linux. But to
# actually use the OS keyring for secret-broker token storage, a D-Bus
# session bus + a Secret Service daemon (gnome-keyring, kwallet, or
# pass-secret-service) must be available at runtime. Headless servers /
# minimal containers typically lack both. Tell the user about the
# BWS_ACCESS_TOKEN fallback up-front — install completed successfully
# either way.
if [ "$(uname -s)" = "Linux" ]; then
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ ! -S "/run/user/$(id -u 2>/dev/null)/bus" ]; then
    echo ""
    echo "OPTIONAL_NOTICE=no D-Bus session bus detected"
    echo "aiplus runs fine here. To use OS keyring storage for secret-broker"
    echo "tokens, you would need a D-Bus session bus + a Secret Service daemon"
    echo "(gnome-keyring / kwallet / pass-secret-service). For headless /"
    echo "container use, set BWS_ACCESS_TOKEN as an environment variable"
    echo "instead — keyring is optional, not required."
  fi
fi

case ":$PATH:" in
  *":$INSTALL_DIR:"*)
    ;;
  *)
    echo "PATH_NOTICE=$INSTALL_DIR is not on PATH"
    echo "Add this to your shell profile if you want to run aiplus from any terminal:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
esac

# ─────────────────────────────────────────────────────────────────────
# P1.7: MCP auto-registration. If we detect codex / claude-code /
# opencode installed (via their config dirs in $HOME), offer to run
# `aiplus mcp-register` for the user — this is the step that makes the
# MCP tools (agent_route, agent_status, etc.) callable from those
# runtimes. Without it, the binary install is "ready" but the agent
# workflow won't actually fire.
# ─────────────────────────────────────────────────────────────────────
detect_runtime_count() {
  count=0
  [ -d "$HOME/.codex" ] && count=$((count + 1))
  [ -d "$HOME/.claude" ] && count=$((count + 1))
  [ -d "$HOME/.opencode" ] && count=$((count + 1))
  echo "$count"
}

runtime_count=$(detect_runtime_count)
should_register=0
case "$REGISTER_MCP" in
  yes)
    should_register=1
    ;;
  no)
    should_register=0
    ;;
  "")
    # No explicit flag. Prompt only if we have a TTY and at least one
    # runtime is detected. Headless installs (CI, curl|bash piped to
    # bash without a tty) silently skip the prompt.
    if [ "$runtime_count" -gt 0 ] && [ -t 0 ] && [ -t 1 ]; then
      printf "Detected %d installed runtime(s) (codex/claude/opencode).\n" "$runtime_count"
      printf "Register aiplus MCP server with them now? This makes the agent_route\n"
      printf "and other PI tools callable from inside those runtimes. [Y/n] "
      read -r answer
      case "$answer" in
        n|N|no|NO) should_register=0 ;;
        *)         should_register=1 ;;
      esac
    fi
    ;;
esac

if [ "$should_register" = 1 ]; then
  echo ""
  echo "Running: $INSTALL_DIR/aiplus mcp-register"
  if "$INSTALL_DIR/aiplus" mcp-register; then
    echo "MCP_REGISTER_FROM_INSTALLER=OK"
  else
    echo "MCP_REGISTER_FROM_INSTALLER=FAIL — you can retry manually: aiplus mcp-register" >&2
  fi
elif [ "$runtime_count" -gt 0 ] && [ -z "$REGISTER_MCP" ]; then
  # Headless / non-tty install with detected runtimes — print the hint
  # so users know about mcp-register even when we can't prompt.
  echo ""
  echo "MCP_HINT detected $runtime_count runtime(s) but skipped the register prompt (no tty)"
  echo "Run \`aiplus mcp-register\` to enable agent_route + other MCP tools."
fi

echo "Next:"
echo "  cd MyProject"
echo "  aiplus install claude-code"
echo "  mother                 (or: aiplus — same binary)"
