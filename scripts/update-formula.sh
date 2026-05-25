#!/usr/bin/env bash
set -euo pipefail

# Updates Formula/polymarket.rb with real SHA256 hashes from a GitHub Release.
# Usage: scripts/update-formula.sh v0.1.0

TAG="${1:?Usage: $0 <version-tag>  (e.g. v0.1.0)}"
VERSION="${TAG#v}"  # strip leading 'v'

REPO="Polymarket/polymarket-cli"
CHECKSUMS_URL="https://github.com/${REPO}/releases/download/${TAG}/checksums.txt"
FORMULA="Formula/polymarket.rb"

echo "Fetching checksums for ${TAG}..."
CHECKSUMS=$(curl -sSfL "$CHECKSUMS_URL")

get_sha() {
  local target="$1"
  local sha
  sha=$(echo "$CHECKSUMS" | grep "polymarket-${TAG}-${target}.tar.gz" | awk '{print $1}')
  if [ -z "$sha" ]; then
    echo "ERROR: No checksum found for target ${target}" >&2
    exit 1
  fi
  echo "$sha"
}

SHA_X86_MAC=$(get_sha "x86_64-apple-darwin")
SHA_ARM_MAC=$(get_sha "aarch64-apple-darwin")
SHA_X86_LINUX=$(get_sha "x86_64-unknown-linux-gnu")
SHA_ARM_LINUX=$(get_sha "aarch64-unknown-linux-gnu")

echo "Writing ${FORMULA} for version ${VERSION}..."

cat > "$FORMULA" << RUBY
class Polymarket < Formula
  desc "CLI for Polymarket — browse markets, trade, and manage positions"
  homepage "https://github.com/${REPO}"
  version "${VERSION}"
  license "MIT"

  on_macos do
    on_intel do
      url "https://github.com/${REPO}/releases/download/v#{version}/polymarket-v#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "${SHA_X86_MAC}"
    end

    on_arm do
      url "https://github.com/${REPO}/releases/download/v#{version}/polymarket-v#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "${SHA_ARM_MAC}"
    end
  end

  on_linux do
    on_intel do
      url "https://github.com/${REPO}/releases/download/v#{version}/polymarket-v#{version}-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "${SHA_X86_LINUX}"
    end

    on_arm do
      url "https://github.com/${REPO}/releases/download/v#{version}/polymarket-v#{version}-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "${SHA_ARM_LINUX}"
    end
  end

  def install
    bin.install "polymarket"
  end

  test do
    assert_match "polymarket", shell_output("#{bin}/polymarket --version")
  end
end
RUBY

echo "Done. Updated ${FORMULA} with version ${VERSION}"
echo "  x86_64-apple-darwin:       ${SHA_X86_MAC}"
echo "  aarch64-apple-darwin:      ${SHA_ARM_MAC}"
echo "  x86_64-unknown-linux-gnu:  ${SHA_X86_LINUX}"
echo "  aarch64-unknown-linux-gnu: ${SHA_ARM_LINUX}"
