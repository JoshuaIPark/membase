#!/bin/sh
set -e

REPO="Polymarket/polymarket-cli"
BINARY="polymarket"
INSTALL_DIR="/usr/local/bin"

get_target() {
  os=$(uname -s)
  arch=$(uname -m)

  case "$os" in
    Darwin)
      case "$arch" in
        x86_64) echo "x86_64-apple-darwin" ;;
        arm64)  echo "aarch64-apple-darwin" ;;
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
      esac
      ;;
    Linux)
      case "$arch" in
        x86_64)  echo "x86_64-unknown-linux-gnu" ;;
        aarch64) echo "aarch64-unknown-linux-gnu" ;;
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;;
      esac
      ;;
    *) echo "Unsupported OS: $os" >&2; exit 1 ;;
  esac
}

main() {
  target=$(get_target)

  tag=$(curl -sSf "https://api.github.com/repos/${REPO}/releases/latest" | grep '"tag_name"' | cut -d'"' -f4)
  if [ -z "$tag" ]; then
    echo "Error: could not determine latest release" >&2
    exit 1
  fi

  tarball_name="${BINARY}-${tag}-${target}.tar.gz"
  url="https://github.com/${REPO}/releases/download/${tag}/${tarball_name}"
  checksums_url="https://github.com/${REPO}/releases/download/${tag}/checksums.txt"

  echo "Installing ${BINARY} ${tag} (${target})..."

  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT

  curl -sSfL "$url" -o "$tmpdir/$tarball_name"
  curl -sSfL "$checksums_url" -o "$tmpdir/checksums.txt"

  expected_hash=$(grep "$tarball_name" "$tmpdir/checksums.txt" | awk '{print $1}')
  if [ -z "$expected_hash" ]; then
    echo "Error: no checksum found for $tarball_name" >&2
    exit 1
  fi

  if command -v sha256sum >/dev/null 2>&1; then
    actual_hash=$(sha256sum "$tmpdir/$tarball_name" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    actual_hash=$(shasum -a 256 "$tmpdir/$tarball_name" | awk '{print $1}')
  else
    echo "Error: need sha256sum or shasum to verify download" >&2
    exit 1
  fi

  if [ "$actual_hash" != "$expected_hash" ]; then
    echo "Error: checksum mismatch!" >&2
    echo "  Expected: $expected_hash" >&2
    echo "  Got:      $actual_hash" >&2
    echo "The downloaded file may have been tampered with. Aborting." >&2
    exit 1
  fi

  echo "Checksum verified."
  tar xzf "$tmpdir/$tarball_name" -C "$tmpdir"

  if [ -w "$INSTALL_DIR" ]; then
    mv "$tmpdir/$BINARY" "$INSTALL_DIR/$BINARY"
  else
    sudo mv "$tmpdir/$BINARY" "$INSTALL_DIR/$BINARY"
  fi

  chmod +x "$INSTALL_DIR/$BINARY"

  echo "Installed ${BINARY} to ${INSTALL_DIR}/${BINARY}"
  echo "Run 'polymarket --help' to get started."
}

main
